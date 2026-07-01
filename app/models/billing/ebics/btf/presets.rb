# frozen_string_literal: true

module Billing
  class EBICS
    module Btf
      class Presets
        def self.swiss_camt054(version: "04")
          btd(
            service_name: "REP",
            scope: "CH",
            container: "ZIP",
            message_name: "camt.054",
            version: version)
        end

        def self.german_camt053(version: "08")
          btd(
            service_name: "EOP",
            scope: "DE",
            container: "ZIP",
            message_name: "camt.053",
            version: version)
        end

        def self.payment_download(country_code:, version: nil)
          case country_code
          when "CH"
            swiss_camt054(version: version || "04")
          when "DE"
            german_camt053(version: version || "08")
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
