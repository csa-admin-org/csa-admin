# frozen_string_literal: true

module Billing
  class EBICS
    module Btf
      class PaymentDownload
        SERVICE_KEYS = %w[service_name scope service_option container message_name version].freeze
        VERSION = "08"

        def self.effective_settings(connection)
          settings = connection.settings.to_h.deep_stringify_keys.deep_dup
          payments = settings.dig("downloads", "payments")
          return settings unless payment_config?(payments)

          apply_version!(payments["btf"], advertised_services(connection.capabilities))
          settings
        end

        def self.apply_version!(btf, services)
          btf["version"] = VERSION if version_advertised?(btf, services)
          btf
        end

        def self.advertised_services(capabilities)
          h005 = capabilities.to_h.deep_stringify_keys.fetch("h005") { {} }
          downloads = Array(h005["htd_btf_downloads"]).filter_map { |info|
            info.to_h.deep_stringify_keys["service"]
          }
          downloads + Array(h005["haa_available_downloads"])
        end

        def self.payment_config?(payments)
          payments = payments.to_h.deep_stringify_keys
          btf = payments["btf"]
          return false unless payments["mode"] == "btf" && btf.is_a?(Hash)

          order_type = btf.to_h.deep_stringify_keys["order_type"]
          order_type.blank? || order_type == "BTD"
        end

        def self.version_advertised?(btf, services)
          identity = tuple(btf).except("version")
          return false if identity.blank?

          Array(services).any? { |service|
            advertised = tuple(service)
            advertised.except("version") == identity && advertised["version"] == VERSION
          }
        end
        private_class_method :version_advertised?

        def self.tuple(attributes)
          attributes.to_h.deep_stringify_keys.slice(*SERVICE_KEYS).compact_blank
        end
        private_class_method :tuple
      end
    end
  end
end
