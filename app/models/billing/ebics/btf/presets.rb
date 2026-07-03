# frozen_string_literal: true

module Billing
  class EBICS
    module Btf
      class Presets
        def self.camt054(service_name:, scope:, version:, container: "ZIP")
          btd(
            service_name: service_name,
            scope: scope,
            container: container,
            message_name: "camt.054",
            version: version)
        end

        def self.camt053(service_name:, scope:, version:, container: "ZIP")
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
            camt053(service_name: "EOP", scope: "DE", version: version || "08")
          else
            raise UnsupportedOperation, "No EBICS BTF payment download preset for #{country_code.inspect}"
          end
        end

        def self.btd(attributes)
          {
            "order_type" => "BTD",
            "service_name" => attributes.fetch(:service_name),
            "scope" => attributes.fetch(:scope),
            "container" => attributes.fetch(:container),
            "message_name" => attributes.fetch(:message_name),
            "version" => attributes.fetch(:version)
          }
        end
      end
    end
  end
end
