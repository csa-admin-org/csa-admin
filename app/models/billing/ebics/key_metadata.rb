# frozen_string_literal: true

module Billing
  class EBICS
    module KeyMetadata
      TARGET_BITS = 4096
      REQUIRED_CREDENTIALS = %w[keys secret url host_id participant_id client_id].freeze
      PARTICIPANT_KEY_VERSIONS = %w[A006 X002 E002].freeze
      BANK_KEY_SUFFIXES = %w[.X002 .E002].freeze

      module_function

      def bank_key?(name)
        name.to_s.include?(".")
      end

      def split(metadata)
        metadata.to_h.deep_stringify_keys.then do |keys|
          {
            "participant" => keys.reject { |name, _attributes| bank_key?(name) },
            "bank" => keys.select { |name, _attributes| bank_key?(name) }
          }
        end
      end

      def for_keys(keys)
        keys.keys.sort.index_with do |name|
          key = Key.new(keys.fetch(name))
          {
            "role" => bank_key?(name) ? "bank" : "participant",
            "bits" => key.bits,
            "public_digest" => key.public_digest
          }
        end
      end

      def required_credentials_present?(credentials)
        attributes = credentials.to_h.deep_stringify_keys
        REQUIRED_CREDENTIALS.all? { |key| attributes[key].present? }
      end

      def inspectable_key_summary(credentials)
        attributes = credentials.to_h.deep_stringify_keys
        return {} unless required_credentials_present?(attributes)

        KeyStore.new(attributes).key_summary
      rescue => e
        inspection_error(e)
      end

      def inspection_error(error, message: "Unable to inspect EBICS keys")
        {
          "error" => {
            "class" => error.class.name,
            "message" => message
          }
        }
      end

      def participant_keys_present?(summary)
        versions = summary.fetch("participant_key_versions", [])
        PARTICIPANT_KEY_VERSIONS.all? { |version| versions.include?(version) }
      end

      def bank_public_keys_present?(summary)
        versions = summary.fetch("bank_key_versions", [])
        BANK_KEY_SUFFIXES.all? { |suffix| versions.any? { |version| version.end_with?(suffix) } }
      end
    end
  end
end
