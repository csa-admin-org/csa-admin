# frozen_string_literal: true

require "test_helper"
require "stringio"

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
    assert_payment_data [
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
    assert_payment_data [
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
    assert_payment_data [
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
    assert_payment_data [
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
    assert_payment_data [
      Billing::CamtFile::PaymentData.new(
        invoice_id: 1,
        member_id: 42,
        amount: 460,
        date: Date.new(2026, 2, 25),
        origin: "camt.053")
    ], file.payments_data
  end

  test "reuses a CAMT fingerprint on replay and distinguishes bank references" do
    xml = file_fixture("camt054.xml").read
    replay = Billing::CamtFile.new(xml).payments_data.first
    distinct_reference = Billing::CamtFile.new(
      xml.sub("ZV20201113/371247/2", "ZV20201113/371247/3")).payments_data.first

    assert_equal replay.fingerprint, Billing::CamtFile.new(xml).payments_data.first.fingerprint
    assert_not_equal replay.fingerprint, distinct_reference.fingerprint
    assert_equal replay.amount, distinct_reference.amount
    assert_equal replay.date, distinct_reference.date
  end

  test "uses every CAMT fingerprint identity tier" do
    transaction = Struct.new(:bank_reference, :transaction_id)
    entry = Struct.new(:bank_reference, :transactions)
    file = Billing::CamtFile.new

    entry_with_transaction_reference = entry.new("entry-reference", [ transaction.new("transaction-reference", "transaction-id") ])
    assert_equal(
      fingerprint(file, "camt.054", entry_with_transaction_reference, transaction.new("transaction-reference", "other-id")),
      fingerprint(file, "camt.054", entry_with_transaction_reference, transaction.new("transaction-reference", "transaction-id")))
    assert_equal(
      fingerprint(file, "camt.053", entry_with_transaction_reference, transaction.new("transaction-reference", "transaction-id")),
      fingerprint(file, "camt.054", entry_with_transaction_reference, transaction.new("transaction-reference", "transaction-id")))
    assert_not_equal(
      fingerprint(file, "camt.054", entry_with_transaction_reference, transaction.new("transaction-reference", "transaction-id")),
      fingerprint(file, "camt.054", entry_with_transaction_reference, transaction.new("other-reference", "transaction-id")))

    entry_with_transaction_id = entry.new("entry-reference", [ transaction.new(nil, "transaction-id") ])
    assert_equal(
      fingerprint(file, "camt.054", entry_with_transaction_id, transaction.new(nil, "transaction-id")),
      fingerprint(file, "camt.054", entry_with_transaction_id, transaction.new(nil, "transaction-id")))
    assert_not_equal(
      fingerprint(file, "camt.054", entry_with_transaction_id, transaction.new(nil, "transaction-id")),
      fingerprint(file, "camt.054", entry_with_transaction_id, transaction.new(nil, "other-id")))

    transactions = [ transaction.new(nil, nil), transaction.new(nil, nil) ]
    entry_with_reference = entry.new("entry-reference", transactions)
    assert_not_equal(
      fingerprint(file, "camt.054", entry_with_reference, transactions.first, transaction_index: 0),
      fingerprint(file, "camt.054", entry_with_reference, transactions.second, transaction_index: 1))

    entry_without_references = entry.new(nil, [ transaction.new(nil, nil) ])
    assert_equal(
      fingerprint(file, "camt.054", entry_without_references, entry_without_references.transactions.first, xml_digest: "document"),
      fingerprint(file, "camt.054", entry_without_references, entry_without_references.transactions.first, xml_digest: "document"))
    assert_not_equal(
      fingerprint(file, "camt.054", entry_without_references, entry_without_references.transactions.first, xml_digest: "document"),
      fingerprint(file, "camt.054", entry_without_references, entry_without_references.transactions.first, xml_digest: "changed-document"))
  end

  test "rewinds CAMT IOs before and after parsing" do
    io = StringIO.new(file_fixture("camt054.xml").read)
    io.read(10)
    file = Billing::CamtFile.new(io)

    first = file.payments_data
    assert_equal 0, io.pos
    second = file.payments_data

    assert_equal first.map(&:fingerprint), second.map(&:fingerprint)
    assert_equal 0, io.pos
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

  def fingerprint(file, origin, entry, transaction, entry_index: 0, transaction_index: 0, xml_digest: "document")
    file.send(
      :payment_fingerprint,
      origin,
      entry: entry,
      transaction: transaction,
      entry_index: entry_index,
      transaction_index: transaction_index,
      xml_digest: xml_digest)
  end

  def assert_payment_data(expected, actual)
    assert_equal expected, actual.map { Billing::CamtFile::PaymentData.new(it.to_h.except(:fingerprint)) }
    actual.each { assert_match(/\A[0-9a-f]{64}\z/, it.fingerprint) }
  end

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
