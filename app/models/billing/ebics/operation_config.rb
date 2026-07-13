# frozen_string_literal: true

module Billing
  class EBICS
    class OperationConfig
      def initialize(settings = {})
        @settings = (settings || {}).to_h.deep_stringify_keys
      end

      def payment_download
        btf_operation(settings.dig("downloads", "payments"), kind: "payment_download", order_type: "BTD")
      end

      def sepa_direct_debit_upload
        operation = btf_operation(sepa_direct_debit_upload_settings, kind: "sepa_direct_debit_upload", order_type: "BTU")
        if operation.btf.values_at("scope", "container").any?(&:present?)
          raise UnsupportedOperation, "EBICS BTF SEPA direct debit uploads require a non-container service"
        end

        operation
      end

      def sepa_direct_debit_upload_schema
        sepa_direct_debit_upload_settings["schema"].presence ||
          btf_pain_schema ||
          raise(UnsupportedOperation, "Missing EBICS BTF SEPA direct debit upload schema")
      end

      private

      attr_reader :settings

      def sepa_direct_debit_upload_settings
        @sepa_direct_debit_upload_settings ||=
          (settings.dig("uploads", "sepa_direct_debit") || {}).to_h.deep_stringify_keys
      end

      def btf_pain_schema
        btf = sepa_direct_debit_upload_settings["btf"].to_h.deep_stringify_keys
        return unless btf["message_name"] == "pain.008" && btf["version"].present?

        "pain.008.001.#{btf.fetch("version").to_s.rjust(2, "0")}"
      end

      def btf_operation(attributes, kind:, order_type:)
        attributes = (attributes || {}).to_h.deep_stringify_keys
        mode = attributes["mode"].presence
        unless mode == "btf"
          raise UnsupportedOperation, "Active EBICS #{kind} must use explicit BTF settings"
        end

        btf = attributes["btf"].to_h.deep_stringify_keys
        raise UnsupportedOperation, "Missing EBICS BTF #{kind} settings" if btf.blank?
        raise UnsupportedOperation, "Active EBICS #{kind} must use #{order_type} BTF settings" unless btf["order_type"] == order_type

        Operation.btf(btf)
      end
    end
  end
end
