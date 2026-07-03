# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"

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

        def download_postprocess_skipped?
          report_text.include?("EBICS_DOWNLOAD_POSTPROCESS_SKIPPED") ||
            report_text.include?("Negative acknowledgement received")
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

        def next_segment_number
          segment_number.to_i + 1
        end

        def segmented?
          segment_number.present?
        end

        def last_segment?
          doc.at_xpath("//h:header/h:mutable/h:SegmentNumber[@lastSegment='true']", h: H005_NAMESPACE).present?
        end

        def order_data_present?
          text("//h:OrderData").present?
        end

        def order_data_encrypted
          Base64.decode64(text("//h:OrderData"))
        end

        def transaction_key_present?
          text("//h:TransactionKey").present?
        end

        def transaction_key
          encrypted_key = Base64.decode64(text("//h:TransactionKey"))
          client.e.key.private_decrypt(encrypted_key)
        end

        def order_data
          Payload.new(responses: [ self ]).order_data
        end

        def files(container: nil)
          Payload.new(responses: [ self ], container: container).files
        end

        def digest_valid?
          return false unless digest_node

          authenticated = doc.xpath("//*[@authenticate='true']").map(&:canonicalize).join
          digest = Base64.encode64(OpenSSL::Digest::SHA256.digest(authenticated)).strip
          digest == digest_node.content
        end

        def signature_valid?
          return false unless signature_node && signature_value_node

          client.bank_x.key.verify(
            OpenSSL::Digest::SHA256.new,
            Base64.decode64(signature_value_node.content),
            signature_node.canonicalize)
        end

        private
          attr_reader :client

          def mutable_return_code
            text("//h:header/h:mutable/h:ReturnCode")
          end

          def system_return_code
            doc.xpath("//xmlns:SystemReturnCode/xmlns:ReturnCode", xmlns: "http://www.ebics.org/H000").text
          end

          def digest_node
            doc.at_xpath("//ds:DigestValue", ds: DownloadRequest::XMLDSIG_NAMESPACE)
          end

          def signature_node
            doc.at_xpath("//ds:SignedInfo", ds: DownloadRequest::XMLDSIG_NAMESPACE)
          end

          def signature_value_node
            doc.at_xpath("//ds:SignatureValue", ds: DownloadRequest::XMLDSIG_NAMESPACE)
          end

          def text(xpath)
            doc.xpath(xpath, h: H005_NAMESPACE).text
          end
      end
    end
  end
end
