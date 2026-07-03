# frozen_string_literal: true

require "test_helper"

class Billing::CamtFileTest < ActiveSupport::TestCase
  test "parser identifies supported CAMT origins" do
    parser = Billing::CamtFile::Parser.new

    assert_equal "camt.053", parser.parse(file_fixture("camt053.xml")).origin
    assert_equal "camt.053", parser.parse(file_fixture("camt053_reversal.xml")).origin
    assert_equal "camt.054", parser.parse(file_fixture("camt054.xml")).origin
    assert_equal "camt.054", parser.parse(file_fixture("camt054_001_08.xml")).origin
  end

  test "parser wraps unsupported CAMT files with the original error" do
    error = assert_raises(Billing::CamtFile::Parser::UnsupportedFileError) do
      Billing::CamtFile::Parser.new.parse(file_fixture("camt_wrong.xml"))
    end

    assert_instance_of ArgumentError, error.original_error
    assert_equal error.original_error.message, error.message
  end

  test "returns payment data from CAMT.054 file" do
    file = Billing::CamtFile.new(file_fixture("camt054.xml"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 42,
        amount: 1,
        date: Date.new(2020, 11, 13, 11),
        origin: "camt.054"
      )
    ], file.payments_data
  end

  test "returns payment data from CAMT.054.001.08 file" do
    file = Billing::CamtFile.new(file_fixture("camt054_001_08.xml"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 42,
        amount: 1,
        date: Date.new(2020, 11, 13, 11),
        origin: "camt.054"
      )
    ], file.payments_data
  end

  test "returns payment data from CAMT.053 file" do
    org(country_code: "DE")
    file = Billing::CamtFile.new(file_fixture("camt053.xml"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 42,
        amount: 1,
        date: Date.new(2013, 12, 27),
        origin: "camt.053"
      )
    ], file.payments_data
  end

  test "returns reversal payment data from CAMT.053 file" do
    org(country_code: "DE")
    file = Billing::CamtFile.new(file_fixture("camt053_reversal.xml"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 612,
        member_id: 41,
        amount: -106.35,
        date: Date.new(2025, 9, 16),
        origin: "camt.053")
    ], file.payments_data
  end

  test "returns payment data from CAMT.053 entry without TxDtls" do
    file = Billing::CamtFile.new(file_fixture("camt053_no_txdtls.xml"))
    assert_equal [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 42,
        amount: 460,
        date: Date.new(2026, 2, 25),
        origin: "camt.053")
    ], file.payments_data
  end

  test "notifies unknown CAMT.054 payment references" do
    event = EventRecorder.new
    file = Billing::CamtFile.new(file_fixture("camt054_ref_with_letters.xml"))

    with_rails_event(event) do
      assert_empty file.payments_data
    end

    assert_equal 1, event.notifications.size
    name, payload = event.notifications.first
    assert_equal :unknown_payment_reference, name
    assert_equal "camt.054", payload.fetch(:origin)
    assert_equal 1, payload.fetch(:amount)
    assert_equal Date.new(2020, 11, 13, 11), payload.fetch(:date)
    assert_equal "ABCD000000000000000001ABCD1", payload.fetch(:ref)
  end

  test "raises for invalid CAMT namespace and reports sanitized metadata" do
    error = ErrorRecorder.new
    file = Billing::CamtFile.new(file_fixture("camt_wrong.xml"))

    with_rails_error(error) do
      assert_raises(Billing::CamtFile::UnsupportedFileError) { file.payments_data }
    end

    _reported_error, context = error.unexpected_errors.first
    assert_equal 1, context.fetch("files_count")
    assert_equal "Document", context.dig("files", 0, "root")
    assert_equal "urn:iso:std:iso:20022:tech:xsd:camt.053.001.04", context.dig("files", 0, "namespace")
    assert_equal "camt.053.001.04", context.dig("files", 0, "message_version")
    assert_not_includes context.to_json, "BkToCstmrDbtCdtNtfctn"
  end

  test "raises for invalid CAMT file" do
    file = Billing::CamtFile.new(file_fixture("camt_invalid.xml"))
    assert_raises(Billing::CamtFile::UnsupportedFileError) { file.payments_data }
  end

  private

  def with_rails_event(event)
    original = Rails.method(:event)
    Rails.define_singleton_method(:event) { event }
    yield
  ensure
    Rails.define_singleton_method(:event, original)
  end

  class EventRecorder
    attr_reader :notifications

    def initialize
      @notifications = []
    end

    def notify(name, **payload)
      @notifications << [ name, payload ]
    end
  end
end
