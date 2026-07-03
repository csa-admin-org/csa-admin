# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Billing::PaymentsProcessorTest < ActiveSupport::TestCase
  PaymentData = Billing::CamtFile::PaymentData

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

  class ProcessPaymentsConnection
    attr_reader :processed

    def process_payments!
      @processed = true
    end
  end
end
