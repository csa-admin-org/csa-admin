# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"
require "stringio"
require "zip"
require "zlib"

module Billing
  class EBICS
    module Btf
      class Response
        H005_NAMESPACE = DownloadRequest::H005_NAMESPACE
        OK_CODES = [ "", "000000", "011000" ].freeze
        NO_DOWNLOAD_DATA_CODE = "090005"

        def initialize(client:, xml:)
          @client = client
          @doc = Nokogiri::XML(xml)
        end

        attr_reader :doc

        def ok?
          !technical_error? && !business_error?
        end

        def technical_error?
          !OK_CODES.include?(technical_code)
        end

        def business_error?
          ![ "", "000000" ].include?(business_code)
        end

        def no_download_data?
          return_code == NO_DOWNLOAD_DATA_CODE || report_text.include?("EBICS_NO_DOWNLOAD_DATA_AVAILABLE")
        end

        def return_code
          business_code.presence || technical_code
        end

        def technical_code
          mutable_return_code.presence || system_return_code
        end

        def business_code
          text("//h:body/h:ReturnCode")
        end

        def report_text
          text("//h:ReportText")
        end

        def transaction_id
          text("//h:header/h:static/h:TransactionID")
        end

        def segment_number
          text("//h:header/h:mutable/h:SegmentNumber")
        end

        def last_segment?
          doc.at_xpath("//h:header/h:mutable/h:SegmentNumber[@lastSegment='true']", h: H005_NAMESPACE).present?
        end

        def order_data
          encrypted_data = Base64.decode64(text("//h:OrderData"))
          inflated_data(decrypt_order_data(encrypted_data))
        end

        def files(container: nil)
          return [ order_data ] unless container.to_s.casecmp("ZIP").zero?

          unzip(order_data)
        end

        private
          attr_reader :client

          def mutable_return_code
            text("//h:header/h:mutable/h:ReturnCode")
          end

          def system_return_code
            doc.xpath("//xmlns:SystemReturnCode/xmlns:ReturnCode", xmlns: "http://www.ebics.org/H000").text
          end

          def decrypt_order_data(encrypted_data)
            cipher = OpenSSL::Cipher.new("aes-128-cbc")
            cipher.decrypt
            cipher.padding = 0
            cipher.key = transaction_key
            cipher.update(encrypted_data) + cipher.final
          end

          def transaction_key
            encrypted_key = Base64.decode64(text("//h:TransactionKey"))
            client.e.key.private_decrypt(encrypted_key)
          end

          def inflated_data(data)
            Zlib::Inflate.inflate(data)
          end

          def unzip(data)
            files = []
            Zip::File.open_buffer(StringIO.new(data)) do |zip|
              zip.reject(&:directory?).each { |entry| files << entry.get_input_stream.read }
            end
            files
          end

          def text(xpath)
            doc.xpath(xpath, h: H005_NAMESPACE).text
          end
      end
    end
  end
end
