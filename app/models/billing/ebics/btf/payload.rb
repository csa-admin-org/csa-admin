# frozen_string_literal: true

require "openssl"
require "stringio"
require "zip"
require "zlib"

module Billing
  class EBICS
    module Btf
      class Payload
        MissingTransactionKey = Class.new(StandardError)

        def initialize(responses:, container: nil)
          @responses = responses
          @container = container
        end

        def files
          return [ order_data ] unless container.to_s.casecmp("ZIP").zero?

          unzip(order_data)
        end

        def order_data
          Zlib::Inflate.inflate(decrypted_order_data)
        end

        private
          attr_reader :responses, :container

          def decrypted_order_data
            cipher = OpenSSL::Cipher.new("aes-128-cbc")
            cipher.decrypt
            cipher.padding = 0
            cipher.key = transaction_key
            cipher.update(encrypted_order_data) + cipher.final
          end

          def encrypted_order_data
            responses.select(&:order_data_present?).map(&:order_data_encrypted).join
          end

          def transaction_key
            responses.find(&:transaction_key_present?)&.transaction_key || raise(MissingTransactionKey, "Missing EBICS transaction key")
          end

          def unzip(data)
            files = []
            Zip::File.open_buffer(StringIO.new(data)) do |zip|
              zip.reject(&:directory?).each { |entry| files << entry.get_input_stream.read }
            end
            files
          end
      end
    end
  end
end
