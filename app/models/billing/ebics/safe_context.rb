# frozen_string_literal: true

require "digest"
require "nokogiri"

module Billing
  class EBICS
    class SafeContext
      OPERATION_KEYS = %w[
        order_type
        service_name
        scope
        service_option
        container
        message_name
        version
        signature_flag
        provider
        kind
      ].freeze

      def self.build(connection: current_connection, operation: nil, **attributes)
        new(connection: connection, operation: operation, attributes: attributes).to_h
      end

      def self.operation(operation)
        case operation
        when Billing::EBICS::Operation
          operation.btf.slice(*OPERATION_KEYS).merge("mode" => "btf")
        when Hash
          attributes = operation.deep_stringify_keys
          attributes.slice(*OPERATION_KEYS).merge("mode" => attributes["mode"]).compact
        end
      end

      def self.payload(payload)
        content = read(payload)
        return { "object_class" => payload.class.name } unless content

        xml = Nokogiri::XML(content)
        namespace = xml.root&.namespace&.href
        {
          "bytes" => content.bytesize,
          "sha256" => Digest::SHA256.hexdigest(content),
          "root" => xml.root&.name,
          "namespace" => namespace,
          "message_version" => message_version(namespace)
        }.compact_blank
      end

      def self.payloads(payload_list)
        Array(payload_list).map { |payload| payload(payload) }
      end

      def self.payloads_context(payload_list)
        payload_metadata = payloads(payload_list)
        {
          "files_count" => payload_metadata.size,
          "files" => payload_metadata
        }
      end

      def self.report_unexpected(error, reporter: Rails.error, context: {})
        reporter.unexpected(error, context: context)
      rescue ActiveSupport::ErrorReporter::UnexpectedError
        nil
      end

      def initialize(connection:, operation:, attributes: {})
        @connection = connection
        @operation = operation
        @attributes = attributes
      end

      def to_h
        connection_context
          .merge("operation" => self.class.operation(operation))
          .merge(attributes.deep_stringify_keys)
          .compact_blank
      end

      private

      attr_reader :connection, :operation, :attributes

      def self.current_connection
        Current.org.active_bank_connection
      rescue
        nil
      end

      def self.read(payload)
        case payload
        when String
          payload
        else
          if payload.respond_to?(:read)
            rewind(payload)
            payload.read.to_s.tap { rewind(payload) }
          end
        end
      end

      def self.rewind(payload)
        payload.rewind if payload.respond_to?(:rewind)
      rescue
        nil
      end

      def self.message_version(namespace)
        namespace.to_s[/((?:camt|pain)\.\d{3}\.\d{3}\.\d{2})/, 1]
      end

      def connection_context
        {
          "tenant" => tenant,
          "bank_connection_id" => connection&.id,
          "bank" => connection&.name,
          "provider" => connection&.provider,
          "protocol" => connection&.settings.to_h.dig("protocol")
        }
      end

      def tenant
        Tenant.current
      rescue
        nil
      end
    end
  end
end
