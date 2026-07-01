# frozen_string_literal: true

require "epics"

module Billing
  class EBICS
    class LegacyClient
      def self.setup(credentials, keysize: 2048, client_factory: ::Epics::Client)
        credentials = Credentials.new(credentials)
        new(
          credentials,
          epics_client: client_factory.setup(*credentials.epics_setup_args(keysize)))
      end

      def initialize(credentials, client_factory: ::Epics::Client, epics_client: nil)
        @credentials = Credentials.new(credentials)
        @client_factory = client_factory
        @epics_client = epics_client
      end

      def client
        @epics_client ||= client_factory.new(*credentials.epics_client_args)
      end

      def download(operation, from:, to:)
        ensure_order_type!(operation)
        client.public_send(operation.method_name, from, to)
      rescue ::Epics::Error::BusinessError => e
        if e.message.include?("EBICS_NO_DOWNLOAD_DATA_AVAILABLE")
          raise NoDownloadDataAvailable.new(e)
        else
          raise e
        end
      rescue ::Epics::Error::TechnicalError => e
        raise TechnicalError.new(e)
      end

      def upload(operation, document:)
        ensure_order_type!(operation)
        client.public_send(operation.method_name, document)
      end

      def submit_initialization!
        client.INI && client.HIA
      end

      def ini_letter(bank_name)
        client.ini_letter(bank_name)
      end

      def fetch_bank_keys!
        client.HPB
      end

      def save_keys(path)
        client.save_keys(path)
      end

      def key_summary
        key_bits = client.keys.transform_values { |key| key.key.n.to_i.bit_length }
        participant_keys = key_bits.reject { |name, _bits| name.include?(".") }
        bank_keys = key_bits.select { |name, _bits| name.include?(".") }

        {
          "key_names" => key_bits.keys.sort,
          "key_bits" => key_bits.sort.to_h,
          "participant_key_min_bits" => participant_keys.values.min,
          "bank_key_min_bits" => bank_keys.values.min,
          "participant_key_versions" => participant_keys.keys.sort,
          "bank_key_versions" => bank_keys.keys.sort
        }
      end

      private
        attr_reader :credentials, :client_factory

        def ensure_order_type!(operation)
          return if operation.order_type?

          raise UnsupportedOperation,
            "Legacy EBICS client only supports order-type operations"
        end
    end
  end
end
