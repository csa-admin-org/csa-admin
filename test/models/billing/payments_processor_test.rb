# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Billing::PaymentsProcessorTest < ActiveSupport::TestCase
  PaymentData = Billing::CamtFile::PaymentData

  setup do
    BankConnection.delete_all
  end

  test "retrieve and process delegates to connection process hook" do
    connection = ProcessPaymentsConnection.new
    organization = Struct.new(:bank_connection).new(connection)

    Current.reset
    Organization.stub(:instance, organization) do
      assert Billing::PaymentsProcessor.retrieve_and_process!
    end

    assert connection.processed
  ensure
    Current.reset
  end

  test "retrieve and process marks table-backed BAS imports with no data" do
    connection = BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123", contract_password: "secret" })

    connection.stub(:adapter, PaymentsDataConnection.new([])) do
      Current.org.stub(:active_bank_connection, connection) do
        assert Billing::PaymentsProcessor.retrieve_and_process!
      end
    end

    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_import_attempted_at?
    assert connection.last_no_data_at?
    assert_nil connection.last_import_succeeded_at
    assert_nil connection.last_error_class
    assert_equal "provider_api", connection.status_details.dig("last_import", "operation", "mode")
    assert_equal "bas", connection.status_details.dig("last_import", "operation", "provider")
    assert_equal "payment_import", connection.status_details.dig("last_import", "operation", "kind")
  end

  test "retrieve and process marks table-backed bunq imports as succeeded" do
    invoice = invoices(:annual_fee)
    payment_data = PaymentData.new(
      origin: "bunq",
      member_id: invoice.member_id,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current,
      fingerprint: "bunq-test-#{SecureRandom.hex(4)}")
    connection = BankConnection.create!(
      provider: "bunq",
      active: true,
      state: "ready",
      credentials: bunq_credentials)

    connection.stub(:adapter, PaymentsDataConnection.new([ payment_data ])) do
      Current.org.stub(:active_bank_connection, connection) do
        assert Billing::PaymentsProcessor.retrieve_and_process!
      end
    end

    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_import_attempted_at?
    assert connection.last_import_succeeded_at?
    assert_nil connection.last_no_data_at
    assert_nil connection.last_error_class
    assert_equal 1, connection.status_details.dig("last_import", "payments_count")
    assert_equal "bunq", connection.status_details.dig("last_import", "operation", "provider")
  end

  test "retrieve and process keeps legacy organization bank connection fallback" do
    org(bank_connection_type: "mock", bank_credentials: { password: "secret" })

    assert_empty BankConnection.all
    assert Billing::PaymentsProcessor.retrieve_and_process!
  end

  test "retrieve and process marks table-backed provider errors" do
    error = ErrorRecorder.new
    connection = BankConnection.create!(
      provider: "bunq",
      name: "bunq",
      active: true,
      state: "ready",
      credentials: bunq_credentials)

    with_rails_error(error) do
      connection.stub(:adapter, FailingPaymentsDataConnection.new(Billing::Bunq::AuthenticationError.new("authentication failed"))) do
        Current.org.stub(:active_bank_connection, connection) do
          assert_raises(Billing::Bunq::AuthenticationError) do
            Billing::PaymentsProcessor.retrieve_and_process!
          end
        end
      end
    end

    connection.reload
    assert_equal "errored", connection.health_status
    assert connection.last_import_attempted_at?
    assert_equal "Billing::Bunq::AuthenticationError", connection.last_error_class
    assert_equal "payment_import", connection.status_details.dig("last_error", "operation_kind")
    reported_error, context, _options = error.reports.first
    assert_instance_of Billing::Bunq::AuthenticationError, reported_error
    assert_equal connection.id, context.fetch("bank_connection_id")
    assert_equal "bunq", context.fetch("provider")
    refute_includes context.to_json, bunq_credentials.fetch(:api_key)
    refute_includes context.to_json, bunq_credentials.fetch(:private_key)
  end

  test "creates payment for valid member and invoice" do
    invoice = invoices(:annual_fee)
    member = invoice.member
    data = PaymentData.new(
      origin: "camt.054",
      member_id: member.id,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current)

    assert_difference "Payment.count", 1 do
      Billing::PaymentsProcessor.new([ data ]).process!
    end

    payment = Payment.last
    assert_equal invoice, payment.invoice
    assert_equal 30, payment.amount
    assert_equal "camt.054", payment.origin
  end

  test "skips payment when member_id is missing" do
    invoice = invoices(:annual_fee)
    data = PaymentData.new(
      origin: "camt.054",
      member_id: nil,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current)

    assert_no_difference "Payment.count" do
      Billing::PaymentsProcessor.new([ data ]).process!
    end
  end

  test "skips payment when member does not exist" do
    invoice = invoices(:annual_fee)
    data = PaymentData.new(
      origin: "camt.054",
      member_id: 999999,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current)

    assert_no_difference "Payment.count" do
      Billing::PaymentsProcessor.new([ data ]).process!
    end
  end

  test "skips payment when invoice does not exist" do
    member = members(:john)
    data = PaymentData.new(
      origin: "camt.054",
      member_id: member.id,
      invoice_id: 999999,
      amount: 30,
      date: Date.current)

    assert_no_difference "Payment.count" do
      Billing::PaymentsProcessor.new([ data ]).process!
    end
  end

  test "skips payment when invoice does not belong to member" do
    member = members(:john)
    invoice = invoices(:annual_fee) # belongs to martha, not john
    data = PaymentData.new(
      origin: "camt.054",
      member_id: member.id,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current)

    assert_no_difference "Payment.count" do
      Billing::PaymentsProcessor.new([ data ]).process!
    end
  end

  test "does not create duplicate payment with same fingerprint" do
    invoice = invoices(:annual_fee)
    member = invoice.member
    data = PaymentData.new(
      origin: "camt.054",
      member_id: member.id,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current,
      fingerprint: "unique123")

    assert_difference "Payment.count", 1 do
      Billing::PaymentsProcessor.new([ data ]).process!
    end

    assert_no_difference "Payment.count" do
      Billing::PaymentsProcessor.new([ data ]).process!
    end
  end

  test "raises processing errors when requested" do
    invoice = invoices(:annual_fee)
    member = invoice.member
    data = PaymentData.new(
      origin: "camt.054",
      member_id: member.id,
      invoice_id: invoice.id,
      amount: 0,
      date: Date.current)

    assert_raises(ActiveRecord::RecordInvalid) do
      Billing::PaymentsProcessor.new([ data ], raise_on_error: true).process!
    end
  end

  test "returns early when payments data is empty" do
    assert_no_difference "Payment.count" do
      result = Billing::PaymentsProcessor.new([]).process!
      assert result
    end
  end

  def bunq_credentials
    {
      private_key: OpenSSL::PKey::RSA.new(2048).to_pem,
      installation_token: "test_installation_token",
      api_key: "test_api_key",
      user_id: 12345,
      monetary_account_id: 67890
    }
  end

  class ProcessPaymentsConnection
    attr_reader :processed

    def process_payments!
      @processed = true
    end
  end

  class PaymentsDataConnection
    def initialize(payments_data)
      @payments_data = payments_data
    end

    def payments_data
      @payments_data
    end
  end

  class FailingPaymentsDataConnection
    def initialize(error)
      @error = error
    end

    def payments_data
      raise @error
    end
  end
end
