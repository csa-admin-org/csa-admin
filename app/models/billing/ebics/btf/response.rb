# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"

module Billing
  class EBICS
    module Btf
      class Response
        H005_NAMESPACE = DownloadRequest::H005_NAMESPACE
        RESPONSE_PROFILES = {
          standard: {
            root: "ebicsResponse",
            schema: :response
          },
          key_management: {
            root: "ebicsKeyManagementResponse",
            schema: :key_management_response
          }
        }.freeze
        OK_CODES = [ "", "000000", "011000" ].freeze
        NO_DOWNLOAD_DATA_CODE = "090005"
        MAX_ENCODED_ORDER_DATA_BYTES = 34 * 1024 * 1024
        MAX_ENCRYPTED_ORDER_DATA_BYTES = 25 * 1024 * 1024

        InvalidOrderData = Class.new(StandardError)
        OrderDataTooLarge = Class.new(StandardError)

        def initialize(client:, xml:)
          @client = client
          @response_bytesize = xml.to_s.bytesize
          @doc = Nokogiri::XML(xml) { |config| config.nonet }
        end

        attr_reader :doc, :response_bytesize

        def h005?
          profile.present? &&
            doc.root.namespace&.href == H005_NAMESPACE &&
            doc.root["Version"] == "H005"
        end

        def standard_h005?
          h005? && profile == :standard
        end

        def key_management_h005?
          h005? && profile == :key_management
        end

        def schema_valid?
          return false unless h005?

          SchemaValidator.valid_document?(doc, schema: RESPONSE_PROFILES.fetch(profile).fetch(:schema))
        end

        def critical_fields_unique?
          schema_valid?
        end

        def ok?
          !technical_error? && !business_error?
        end

        def technical_error?
          !OK_CODES.include?(technical_code.to_s)
        end

        def business_error?
          ![ "", "000000" ].include?(business_code.to_s)
        end

        def no_download_data?
          business_code == NO_DOWNLOAD_DATA_CODE
        end

        def download_postprocess_skipped?
          report_text.include?("EBICS_DOWNLOAD_POSTPROCESS_SKIPPED") ||
            report_text.include?("Negative acknowledgement received")
        end

        def return_code
          technical_error? ? technical_code : business_code.presence || technical_code
        end

        def technical_code
          mutable_return_code.presence || system_return_code
        end

        def business_code
          text("/*/h:body/h:ReturnCode")
        end

        def report_text
          text("/*/h:header/h:mutable/h:ReportText")
        end

        def transaction_id
          text("/*/h:header/h:static/h:TransactionID")
        end

        def order_id
          text("/*/h:header/h:mutable/h:OrderID")
        end

        def segment_number
          text("/*/h:header/h:mutable/h:SegmentNumber")
        end

        def next_segment_number
          segment_number.to_i + 1
        end

        def segmented?
          segment_number.present?
        end

        def last_segment?
          segment_number_node&.[]("lastSegment") == "true"
        end

        def order_data_present?
          order_data_node&.content.to_s.present?
        end

        def encoded_order_data_bytes
          encoded_order_data.bytesize
        end

        def order_data_encrypted
          @order_data_encrypted ||= begin
            if encoded_order_data_bytes > MAX_ENCODED_ORDER_DATA_BYTES
              raise OrderDataTooLarge, "EBICS encoded order data segment exceeds #{MAX_ENCODED_ORDER_DATA_BYTES} bytes"
            end

            Base64.strict_decode64(encoded_order_data).tap do |encrypted|
              if encrypted.bytesize > MAX_ENCRYPTED_ORDER_DATA_BYTES
                raise OrderDataTooLarge, "EBICS encrypted order data segment exceeds #{MAX_ENCRYPTED_ORDER_DATA_BYTES} bytes"
              end
            end
          end
        rescue ArgumentError
          raise InvalidOrderData, "Invalid EBICS order data encoding"
        end

        def transaction_key_present?
          transaction_key_node&.content.to_s.present?
        end

        def transaction_key
          encrypted_key = Base64.strict_decode64(encoded_transaction_key)
          client.e.key.private_decrypt(encrypted_key)
        rescue ArgumentError
          raise InvalidOrderData, "Invalid EBICS transaction key encoding"
        end

        def order_data
          Payload.new(responses: [ self ]).order_data
        end

        def files(container: nil)
          Payload.new(responses: [ self ], container: container).files
        end

        def digest_valid?
          signature_verifier.digest_valid?
        end

        def signature_valid?
          signature_verifier.signature_valid?
        end

        private

        attr_reader :client

        def mutable_return_code
          text("/*/h:header/h:mutable/h:ReturnCode")
        end

        def system_return_code
          text("/*/h:SystemReturnCode/h:ReturnCode")
        end

        def signature_verifier
          @signature_verifier ||= ResponseSignatureVerifier.new(client: client, doc: doc)
        end

        def profile
          @profile ||= RESPONSE_PROFILES.find { |_name, attributes|
            attributes.fetch(:root) == doc.root&.name
          }&.first
        end

        def text(xpath)
          nodes(xpath).first&.content.to_s if nodes(xpath).one?
        end

        def segment_number_node
          nodes("/*/h:header/h:mutable/h:SegmentNumber").first if nodes("/*/h:header/h:mutable/h:SegmentNumber").one?
        end

        def order_data_node
          nodes("/*/h:body/h:DataTransfer/h:OrderData").first if nodes("/*/h:body/h:DataTransfer/h:OrderData").one?
        end

        def transaction_key_node
          nodes("/*/h:body/h:DataTransfer/h:DataEncryptionInfo/h:TransactionKey").first if nodes("/*/h:body/h:DataTransfer/h:DataEncryptionInfo/h:TransactionKey").one?
        end

        def encoded_order_data
          @encoded_order_data ||= order_data_node&.content.to_s.gsub(/\s+/, "")
        end

        def encoded_transaction_key
          transaction_key_node&.content.to_s.gsub(/\s+/, "")
        end

        def nodes(xpath)
          doc.xpath(xpath, h: H005_NAMESPACE)
        end
      end
    end
  end
end
