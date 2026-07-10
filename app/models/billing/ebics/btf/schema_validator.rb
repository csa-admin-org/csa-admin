# frozen_string_literal: true

require "nokogiri"

module Billing
  class EBICS
    module Btf
      class SchemaValidator
        H005_NAMESPACE = "urn:org:ebics:H005"
        SCHEMA_DIRECTORY = Rails.root.join("config/ebics/schemas/h005")
        SCHEMAS = {
          response: "ebics_response_H005.xsd",
          key_management_response: "ebics_keymgmt_response_H005.xsd",
          orders: "ebics_orders_H005.xsd"
        }.freeze

        def self.valid?(xml, schema:, root: nil)
          valid_document?(Nokogiri::XML(xml) { |config| config.nonet }, schema:, root:)
        rescue Nokogiri::XML::SyntaxError
          false
        end

        def self.valid_document?(document, schema:, root: nil)
          document.errors.empty? &&
            expected_root?(document, root) &&
            schema_for(schema).validate(document).empty?
        rescue Nokogiri::XML::SyntaxError
          false
        end

        def self.schema_for(schema)
          schemas.fetch(schema) do
            path = SCHEMA_DIRECTORY.join(SCHEMAS.fetch(schema))
            schemas[schema] = File.open(path) { |file| Nokogiri::XML::Schema(file) }
          end
        end

        def self.schemas
          @schemas ||= {}
        end
        private_class_method :schemas

        def self.expected_root?(document, root)
          return true unless root

          document.root&.name == root && document.root.namespace&.href == H005_NAMESPACE
        end
        private_class_method :expected_root?
      end
    end
  end
end
