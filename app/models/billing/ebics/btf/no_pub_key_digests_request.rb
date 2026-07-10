# frozen_string_literal: true

require "nokogiri"
require "securerandom"

module Billing
  class EBICS
    module Btf
      class NoPubKeyDigestsRequest
        include RequestEnvelope

        SUPPORTED_ORDER_TYPES = %w[HPB].freeze

        def initialize(client:, order_type:, nonce: SecureRandom.hex(16), timestamp: Time.current.utc.iso8601, product_name: "CSA Admin", language: "en", signer: nil)
          @client = client
          @order_type = order_type.to_s.upcase
          @nonce = nonce
          @timestamp = timestamp
          @product_name = product_name
          @language = language
          @signer = signer || RequestSigner.new(client)
        end

        def to_xml
          signer.sign(unsigned_xml)
        end

        def unsigned_xml
          ensure_supported_order_type!

          serialize_xml(Nokogiri::XML::Builder.new do |xml|
            xml.ebicsNoPubKeyDigestsRequest(key_management_root_attributes) {
              initialisation_header(
                xml,
                bank_public_key_digests: false,
                transaction_phase: false) { order_details(xml) }
              auth_signature(xml)
              xml.body
            }
          end)
        end

        private

        attr_reader :client, :order_type, :nonce, :timestamp, :product_name, :language, :signer

        def ensure_supported_order_type!
          return if SUPPORTED_ORDER_TYPES.include?(order_type)

          raise UnsupportedOperation, "EBICS no-bank-digest request only supports #{SUPPORTED_ORDER_TYPES.to_sentence}"
        end

        def key_management_root_attributes
          root_attributes.merge("xsi:schemaLocation" => "#{DownloadRequest::H005_NAMESPACE} ebics_keymgmt_request_H005.xsd")
        end

        def order_details(xml)
          xml.OrderDetails {
            xml.AdminOrderType order_type
          }
        end
      end
    end
  end
end
