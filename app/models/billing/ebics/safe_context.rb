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
      PROVIDER_TEXT_KEYS = %w[
        body
        description
        detail
        error
        message
        provider_error
        reason
        report_text
        response_body
        response_text
      ].freeze
      PROVIDER_TEXT_KEY_SUFFIXES = %w[
        _body
        _description
        _detail
        _error
        _message
        _provider_error
        _reason
        _report_text
        _response_text
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

      def self.error_summary(error, operation_kind: nil)
        {
          "error_class" => error.class.name,
          "error_message" => safe_error_message(error, operation_kind: operation_kind),
          "return_code" => error_return_code(error)
        }.compact_blank
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

      def self.sanitize(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, item), sanitized|
            key = key.to_s
            if provider_text_key?(key)
              sanitized["#{key}_length"] = item.to_s.bytesize
              sanitized["#{key}_sha256"] = Digest::SHA256.hexdigest(item.to_s)
            else
              sanitized[key] = sanitize(item)
            end
          end
        when Array
          value.map { |item| sanitize(item) }
        else
          value
        end
      end

      def initialize(connection:, operation:, attributes: {})
        @connection = connection
        @operation = operation
        @attributes = attributes
      end

      def to_h
        self.class.sanitize(
          connection_context
            .merge("operation" => self.class.operation(operation))
            .merge(attributes.deep_stringify_keys))
          .compact_blank
      end

      private

      attr_reader :connection, :operation, :attributes

      def self.provider_text_key?(key)
        PROVIDER_TEXT_KEYS.include?(key) || PROVIDER_TEXT_KEY_SUFFIXES.any? { |suffix| key.end_with?(suffix) }
      end
      private_class_method :provider_text_key?

      def self.safe_error_message(error, operation_kind:)
        return "EBICS response #{error_return_code(error)}" if error_return_code(error).present?
        return "#{operation_kind.to_s.humanize} failed" if operation_kind.present?

        "Bank connection operation failed"
      end
      private_class_method :safe_error_message

      def self.error_return_code(error)
        current = error
        3.times do
          if current.respond_to?(:response)
            response = current.response
            return response.return_code if response&.respond_to?(:return_code)
          end
          break unless current.respond_to?(:original_error)

          current = current.original_error
        end
        nil
      end
      private_class_method :error_return_code

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
