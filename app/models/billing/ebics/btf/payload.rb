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
        PayloadTooLarge = Class.new(StandardError)

        MAX_INFLATED_ORDER_DATA_BYTES = 25 * 1024 * 1024
        MAX_ENCRYPTED_ORDER_DATA_BYTES = 25 * 1024 * 1024
        MAX_ORDER_DATA_SEGMENTS = 100
        MAX_ZIP_FILES = 1_000
        MAX_ZIP_ENTRY_BYTES = 10 * 1024 * 1024
        MAX_ZIP_TOTAL_BYTES = 25 * 1024 * 1024
        READ_CHUNK_BYTES = 64 * 1024

        def initialize(responses:, container: nil)
          @responses = responses
          @container = container
        end

        def files
          return [ order_data ] unless container.to_s.casecmp("ZIP").zero?

          unzip(order_data)
        end

        def order_data
          inflate_limited(decrypted_order_data)
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
          segments = responses.select(&:order_data_present?)
          raise PayloadTooLarge, "EBICS order data has too many segments" if segments.size > MAX_ORDER_DATA_SEGMENTS

          segments.each_with_object(String.new) do |response, encrypted|
            encrypted << response.order_data_encrypted
            ensure_payload_size!(encrypted.bytesize, MAX_ENCRYPTED_ORDER_DATA_BYTES, "EBICS encrypted order data")
          end
        end

        def transaction_key
          responses.find(&:transaction_key_present?)&.transaction_key || raise(MissingTransactionKey, "Missing EBICS transaction key")
        end

        def unzip(data)
          files = []
          total_bytes = 0

          Zip::File.open_buffer(StringIO.new(data)) do |zip|
            entries = zip.reject(&:directory?)
            raise PayloadTooLarge, "EBICS ZIP payload contains too many files (#{entries.size}/#{MAX_ZIP_FILES})" if entries.size > MAX_ZIP_FILES

            entries.each do |entry|
              content = read_zip_entry(entry)
              total_bytes += content.bytesize
              raise PayloadTooLarge, "EBICS ZIP payload is too large" if total_bytes > MAX_ZIP_TOTAL_BYTES

              files << content
            end
          end
          files
        end

        def inflate_limited(data)
          output = +""
          inflater = Zlib::Inflate.new
          offset = 0

          while offset < data.bytesize && !inflater.finished?
            chunk = data.byteslice(offset, READ_CHUNK_BYTES)
            inflater.inflate(chunk) do |inflated|
              output << inflated
              ensure_payload_size!(output.bytesize, MAX_INFLATED_ORDER_DATA_BYTES, "EBICS order data")
            end
            offset += chunk.bytesize
          end
          unless inflater.finished?
            inflater.finish do |inflated|
              output << inflated
              ensure_payload_size!(output.bytesize, MAX_INFLATED_ORDER_DATA_BYTES, "EBICS order data")
            end
          end
          output
        ensure
          inflater&.close
        end

        def read_zip_entry(entry)
          content = +""
          entry.get_input_stream do |stream|
            loop do
              chunk = stream.read(READ_CHUNK_BYTES)
              break unless chunk

              content << chunk
              ensure_payload_size!(content.bytesize, MAX_ZIP_ENTRY_BYTES, "EBICS ZIP entry")
            end
          end
          content
        end

        def ensure_payload_size!(size, maximum, label)
          raise PayloadTooLarge, "#{label} exceeds #{maximum} bytes" if size > maximum
        end
      end
    end
  end
end
