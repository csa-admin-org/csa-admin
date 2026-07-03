# frozen_string_literal: true

module Billing
  class EBICS
    class OperationConfig
      def initialize(settings = {}, country_code: nil)
        @settings = (settings || {}).to_h.deep_stringify_keys
        @country_code = country_code
      end

      def payment_download(country_code: self.country_code)
        operation(
          settings.dig("downloads", "payments"),
          default_order_type: country_code == "CH" ? "Z54" : "C53")
      end

      def sepa_direct_debit_upload
        operation(
          sepa_direct_debit_upload_settings,
          default_order_type: "CDD")
      end

      def sepa_direct_debit_upload_schema
        sepa_direct_debit_upload_settings["schema"].presence ||
          btf_pain_schema ||
          Billing::SEPADirectDebit::SCHEMA
      end

      private

      attr_reader :settings, :country_code

      def sepa_direct_debit_upload_settings
        @sepa_direct_debit_upload_settings ||=
          (settings.dig("uploads", "sepa_direct_debit") || {}).to_h.deep_stringify_keys
      end

      def btf_pain_schema
        btf = sepa_direct_debit_upload_settings["btf"].to_h.deep_stringify_keys
        return unless btf["message_name"] == "pain.008" && btf["version"].present?

        "pain.008.001.#{btf.fetch("version").to_s.rjust(2, "0")}"
      end

      def operation(attributes, default_order_type:)
        attributes = (attributes || {}).to_h.deep_stringify_keys
        mode = attributes["mode"].presence || "order_type"

        case mode
        when "order_type"
          Operation.order_type(attributes["order_type"].presence || default_order_type)
        when "btf"
          Operation.btf(attributes.fetch("btf"))
        else
          raise UnsupportedOperation, "Unsupported EBICS operation mode: #{mode}"
        end
      end
    end
  end
end
