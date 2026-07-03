# frozen_string_literal: true

module Billing
  class EBICS
    module Btf
      class Presets
        def self.camt054(service_name:, scope:, version: nil, container: "ZIP")
          btd(
            service_name: service_name,
            scope: scope,
            container: container,
            message_name: "camt.054",
            version: version)
        end

        def self.camt053(service_name:, scope:, version: nil, container: "ZIP")
          btd(
            service_name: service_name,
            scope: scope,
            container: container,
            message_name: "camt.053",
            version: version)
        end

        def self.payment_download(country_code:, version: nil)
          case country_code
          when "CH"
            camt054(service_name: "REP", scope: "CH", version: version || "04")
          when "DE"
            camt053(service_name: "EOP", scope: "DE", version: version)
          else
            raise UnsupportedOperation, "No EBICS BTF payment download preset for #{country_code.inspect}"
          end
        end

        def self.sepa_direct_debit_status_report(scope: "DE", service_option: "SDD", container: "ZIP", version: nil)
          btd(
            service_name: "REP",
            scope: scope,
            service_option: service_option,
            container: container,
            message_name: "pain.002",
            version: version)
        end

        def self.sepa_direct_debit_upload(scope: nil, service_option: "COR", container: nil, version: "08", signature_flag: true)
          btu(
            service_name: "SDD",
            scope: scope,
            service_option: service_option,
            container: container,
            message_name: "pain.008",
            version: version,
            signature_flag: signature_flag)
        end

        def self.btd(attributes)
          {
            "order_type" => "BTD",
            "service_name" => attributes.fetch(:service_name),
            "scope" => attributes[:scope],
            "service_option" => attributes[:service_option],
            "container" => attributes[:container],
            "message_name" => attributes.fetch(:message_name),
            "version" => attributes[:version]
          }.compact_blank
        end

        def self.btu(attributes)
          {
            "order_type" => "BTU",
            "service_name" => attributes.fetch(:service_name),
            "scope" => attributes[:scope],
            "service_option" => attributes[:service_option],
            "container" => attributes[:container],
            "message_name" => attributes.fetch(:message_name),
            "version" => attributes[:version],
            "signature_flag" => attributes[:signature_flag]
          }.compact
        end
      end
    end
  end
end
