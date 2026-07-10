# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::SafeContextTest < ActiveSupport::TestCase
  test "builds sanitized bank and operation context" do
    BankConnection.delete_all
    connection = BankConnection.create!(
      provider: "ebics",
      name: "MULTIVIA",
      active: false,
      state: "ready",
      credentials: { secret: "secret" },
      settings: {
        "protocol" => "H005",
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "btf",
            "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(scope: "DE", container: "XML", version: nil)
          }
        }
      })
    operation = Billing::EBICS::Operation.btf(connection.settings.dig("uploads", "sepa_direct_debit", "btf"))

    context = Billing::EBICS::SafeContext.build(connection: connection, operation: operation, invoice_id: 123)

    assert_equal "acme", context.fetch("tenant")
    assert_equal connection.id, context.fetch("bank_connection_id")
    assert_equal "MULTIVIA", context.fetch("bank")
    assert_equal "ebics", context.fetch("provider")
    assert_equal "H005", context.fetch("protocol")
    assert_equal "btf", context.dig("operation", "mode")
    assert_equal "BTU", context.dig("operation", "order_type")
    assert_equal "pain.008", context.dig("operation", "message_name")
    assert_equal 123, context.fetch("invoice_id")
    assert_not_includes context.to_json, "secret"
  end

  test "replaces hostile provider text with stable metadata" do
    hostile_text = "https://member:secret@provider.test <Document>member@example.test</Document>"
    context = Billing::EBICS::SafeContext.build(
      report_text: hostile_text,
      error_message: hostile_text,
      response: {
        "detail" => hostile_text,
        "body" => hostile_text,
        "message" => hostile_text
      })

    assert_equal hostile_text.bytesize, context.fetch("report_text_length")
    assert_equal Digest::SHA256.hexdigest(hostile_text), context.fetch("report_text_sha256")
    assert_equal hostile_text.bytesize, context.fetch("error_message_length")
    assert_equal hostile_text.bytesize, context.dig("response", "detail_length")
    assert_equal hostile_text.bytesize, context.dig("response", "body_length")
    assert_equal hostile_text.bytesize, context.dig("response", "message_length")
    assert_not_includes context.to_json, hostile_text
    assert_not_includes context.to_json, "member:secret"
    assert_not_includes context.to_json, "member@example.test"
  end

  test "builds safe error summaries without arbitrary exception text" do
    provider_text = "secret member@example.test <Document>payment data</Document>"

    summary = Billing::EBICS::SafeContext.error_summary(
      RuntimeError.new(provider_text),
      operation_kind: "payment_download")

    assert_equal "RuntimeError", summary.fetch("error_class")
    assert_equal "Payment download failed", summary.fetch("error_message")
    assert_not_includes summary.to_json, provider_text
  end

  test "preserves explicit false operation values" do
    operation = Billing::EBICS::SafeContext.operation(
      "order_type" => "BTU",
      "message_name" => "pain.008",
      "signature_flag" => false)

    refute operation.fetch("signature_flag")
  end

  test "builds XML payload metadata without including payload content" do
    xml = <<~XML
      <Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.054.001.08">
        <Secret>do not leak</Secret>
      </Document>
    XML

    metadata = Billing::EBICS::SafeContext.payload(xml)

    assert_equal xml.bytesize, metadata.fetch("bytes")
    assert_equal "Document", metadata.fetch("root")
    assert_equal "urn:iso:std:iso:20022:tech:xsd:camt.054.001.08", metadata.fetch("namespace")
    assert_equal "camt.054.001.08", metadata.fetch("message_version")
    assert_not_includes metadata.to_json, "do not leak"
  end
end
