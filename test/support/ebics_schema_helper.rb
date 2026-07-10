# frozen_string_literal: true

require "nokogiri"

module EbicsSchemaHelper
  EBICS_H005_SCHEMA_PATH = Rails.root.join("config/ebics/schemas/h005")
  EBICS_H005_SCHEMAS = {
    request: "ebics_request_H005.xsd",
    key_management_request: "ebics_keymgmt_request_H005.xsd",
    response: "ebics_response_H005.xsd",
    key_management_response: "ebics_keymgmt_response_H005.xsd",
    orders: "ebics_orders_H005.xsd",
    signature: "ebics_signature_S002.xsd"
  }.freeze

  def assert_valid_ebics_h005_xml(xml, schema, message = nil)
    errors = ebics_h005_schema(schema).validate(Nokogiri::XML(xml))

    assert_empty errors.map(&:message), message || "Expected XML to validate against #{EBICS_H005_SCHEMAS.fetch(schema)}"
  end

  def ebics_h005_schema(schema)
    @ebics_h005_schemas ||= {}
    @ebics_h005_schemas.fetch(schema) do
      @ebics_h005_schemas[schema] = load_ebics_h005_schema(schema)
    end
  end

  private

  def load_ebics_h005_schema(schema)
    path = EBICS_H005_SCHEMA_PATH.join(EBICS_H005_SCHEMAS.fetch(schema))
    File.open(path) { |file| Nokogiri::XML::Schema(file) }
  end
end
