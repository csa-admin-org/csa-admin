# frozen_string_literal: true

require "nokogiri"
require "securerandom"

module Billing
  class EBICS
    module Btf
      class AdminRequest
        include RequestEnvelope

        SUPPORTED_ORDER_TYPES = %w[HAA HTD].freeze

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
            xml.ebicsRequest(root_attributes) {
              initialisation_header(xml) { order_details(xml) }
              auth_signature(xml)
              xml.body
            }
          end)
        end

        private

        attr_reader :client, :order_type, :nonce, :timestamp, :product_name, :language, :signer

        def ensure_supported_order_type!
          return if SUPPORTED_ORDER_TYPES.include?(order_type)

          raise UnsupportedOperation, "H005 admin probe only supports #{SUPPORTED_ORDER_TYPES.to_sentence}"
        end

        def order_details(xml)
          xml.OrderDetails {
            xml.AdminOrderType order_type
            xml.StandardOrderParams
          }
        end
      end
    end
  end
end
