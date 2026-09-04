# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Billing::PaymentsProcessorTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  PaymentData = Billing::CamtFile::PaymentData

  setup do
    BankConnection.delete_all
  end

  test "retrieve and process delegates to connection process hook" do
    connection = ProcessPaymentsConnection.new
    organization = Struct.new(:active_bank_connection).new(connection)

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

  test "retrieve and process does nothing without an active bank connection" do
    assert_empty BankConnection.all
    assert_nil Billing::PaymentsProcessor.retrieve_and_process!
  end

  test "retrieve and process marks BAS LoginError without raising" do
    recorder = RailsErrorHelper::ErrorRecorder.new
    connection = create_bas_connection

    with_rails_error(recorder) do
      connection.stub(:adapter, FailingPaymentsDataConnection.new(Billing::BAS::LoginError.new("Login issue (200)"))) do
        Current.org.stub(:active_bank_connection, connection) do
          assert_enqueued_emails 2 do
            assert_nil Billing::PaymentsProcessor.retrieve_and_process!
          end
        end
      end
    end

    connection.reload
    assert_equal "errored", connection.health_status
    assert_equal "Billing::BAS::LoginError", connection.last_error_class
    assert connection.last_import_attempted_at?
    assert_nil connection.last_no_data_at
    assert connection.status_details.dig("last_error", "notified_at").present?
    assert_empty recorder.reports
    assert_empty recorder.unexpected_errors
  end

  test "retrieve and process marks BAS UnknownError without mailing or latching" do
    recorder = RailsErrorHelper::ErrorRecorder.new
    connection = create_bas_connection

    with_rails_error(recorder) do
      connection.stub(:adapter, FailingPaymentsDataConnection.new(Billing::BAS::UnknownError.new("BAS login unknown error (302)"))) do
        Current.org.stub(:active_bank_connection, connection) do
          assert_no_enqueued_emails do
            assert_nil Billing::PaymentsProcessor.retrieve_and_process!
          end
        end
      end
    end

    connection.reload
    assert_equal "errored", connection.health_status
    assert_equal "Billing::BAS::UnknownError", connection.last_error_class
    assert connection.last_import_attempted_at?
    assert_not connection.payment_import_blocked?
    assert_nil connection.status_details.dig("last_error", "notified_at")
    assert_empty recorder.reports
    assert_empty recorder.unexpected_errors
  end

  test "retrieve and process skips BAS login latch without calling the adapter" do
    connection = create_bas_connection(
      health_status: "errored",
      last_error_class: "Billing::BAS::LoginError",
      last_import_attempted_at: Time.current)
    adapter = FailingPaymentsDataConnection.new(RuntimeError.new("should not run"))

    connection.stub(:adapter, adapter) do
      Current.org.stub(:active_bank_connection, connection) do
        assert_no_enqueued_emails do
          assert_nil Billing::PaymentsProcessor.retrieve_and_process!
        end
      end
    end

    connection.reload
    assert_equal "errored", connection.health_status
    assert_equal "Billing::BAS::LoginError", connection.last_error_class
  end

  test "retrieve and process runs again after a password update clears the latch" do
    connection = create_bas_connection(
      health_status: "errored",
      last_error_class: "Billing::BAS::LoginError")
    client = Object.new
    client.define_singleton_method(:verify_login!) { true }

    Billing::BAS.stub(:new, client) do
      connection.update_bas_password!("new-secret")
    end

    connection.stub(:adapter, PaymentsDataConnection.new([])) do
      Current.org.stub(:active_bank_connection, connection) do
        assert Billing::PaymentsProcessor.retrieve_and_process!
      end
    end

    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_no_data_at?
  end

  test "retrieve and process does not stamp LoginError after a later password update" do
    connection = create_bas_connection
    adapter = RacePasswordUpdateAdapter.new(connection)

    connection.stub(:adapter, adapter) do
      Current.org.stub(:active_bank_connection, connection) do
        assert_nil Billing::PaymentsProcessor.retrieve_and_process!
      end
    end

    connection.reload
    assert_equal "healthy", connection.health_status
    assert_nil connection.last_error_class
    assert connection.status_details["credentials_updated_at"].present?
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
    assert_empty error.reports
    refute_includes connection.status_details.to_json, bunq_credentials.fetch(:api_key)
    refute_includes connection.status_details.to_json, bunq_credentials.fetch(:private_key)
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

  test "does not create duplicate payment with same fingerprint on replay" do
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

  test "reconciles one legacy CAMT payment across statement and notification origins" do
    invoice = invoices(:annual_fee)
    payment = Payment.create!(
      invoice: invoice,
      amount: 30,
      date: Date.current,
      origin: "camt.053")
    data = PaymentData.new(
      origin: "camt.054",
      member_id: invoice.member_id,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current,
      fingerprint: "camt-cutover")

    assert_no_difference "Payment.count" do
      Billing::PaymentsProcessor.new([ data ], raise_on_error: true).process!
    end

    assert_equal "camt-cutover", payment.reload.fingerprint
    assert_equal "camt.054", payment.origin
  end

  test "reports ambiguous legacy CAMT reconciliation without creating a payment" do
    invoice = invoices(:annual_fee)
    2.times do
      Payment.create!(
        invoice: invoice,
        amount: 30,
        date: Date.current,
        origin: "camt.054")
    end
    data = PaymentData.new(
      origin: "camt.054",
      member_id: invoice.member_id,
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current,
      fingerprint: "camt-ambiguous")
    event = EventRecorder.new

    with_rails_event(event) do
      assert_no_difference "Payment.count" do
        Billing::PaymentsProcessor.new([ data ], raise_on_error: true).process!
      end
    end

    name, payload = event.notifications.sole
    assert_equal :payment_processing_legacy_camt_fingerprint_ambiguous, name
    assert_equal 2, payload.fetch(:payments_count)
    assert_equal [ nil, nil ], Payment.where(
      origin: "camt.054",
      invoice_id: invoice.id,
      amount: 30,
      date: Date.current,
      fingerprint: nil).pluck(:fingerprint)
  end

  test "continues processing after a payment fingerprint race" do
    invoice = invoices(:annual_fee)
    first_payment = PaymentData.new(
      origin: "camt.054",
      member_id: invoice.member_id,
      invoice_id: invoice.id,
      amount: 1,
      date: Date.current,
      fingerprint: "race-#{SecureRandom.hex(4)}")
    second_payment = PaymentData.new(
      origin: "camt.054",
      member_id: invoice.member_id,
      invoice_id: invoice.id,
      amount: 2,
      date: Date.current,
      fingerprint: "next-#{SecureRandom.hex(4)}")
    raced = false

    assert_difference "Payment.count", 2 do
      Payment.stub(:find_or_initialize_by, lambda { |attrs|
    unless raced
      raced = true
      Payment.create!(attrs.merge(origin: first_payment.origin))
    end
    Payment.new(attrs)
      }) do
    assert Billing::PaymentsProcessor.new(
      [ first_payment, second_payment ],
      raise_on_error: true).process!
      end
    end

    assert Payment.exists?(fingerprint: first_payment.fingerprint)
    assert Payment.exists?(fingerprint: second_payment.fingerprint)
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

  def with_rails_event(event)
    original = Rails.method(:event)
    Rails.define_singleton_method(:event) { event }
    yield
  ensure
    Rails.define_singleton_method(:event, original)
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

  class EventRecorder
    attr_reader :notifications

    def initialize
      @notifications = []
    end

    def notify(name, **payload)
      notifications << [ name, payload ]
    end
  end

  def create_bas_connection(**attributes)
    BankConnection.create!({
      provider: "bas",
      active: true,
      state: "ready",
      credentials: {
        account_number: "123",
        contract_number: "IB0043999",
        contract_password: "secret"
      }
    }.merge(attributes))
  end

  class ProcessPaymentsConnection
    attr_reader :processed

    def payment_import_blocked?
      false
    end

    def runtime_adapter
      self
    end

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

  class RacePasswordUpdateAdapter
    def initialize(connection)
      @connection = connection
    end

    def payments_data
      @connection.update_columns(
        health_status: "healthy",
        last_error_class: nil,
        last_error_message: nil,
        status_details: @connection.status_details.to_h.merge(
          "credentials_updated_at" => Time.current.iso8601),
        updated_at: Time.current)
      fail Billing::BAS::LoginError, "Login issue (200)"
    end
  end
end
