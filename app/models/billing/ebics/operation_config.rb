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
          settings.dig("uploads", "sepa_direct_debit"),
          default_order_type: "CDD")
      end

      private
        attr_reader :settings, :country_code

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
