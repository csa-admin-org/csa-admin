# frozen_string_literal: true

require "base64"
require "nokogiri"
require "securerandom"
require "zlib"

module Billing
  class EBICS
    module Btf
      class InitializationRequest
        SUPPORTED_ORDER_TYPES = InitializationOrderData::SUPPORTED_ORDER_TYPES

        def initialize(client:, order_type:, nonce: SecureRandom.hex(16), timestamp: Time.current.utc.iso8601, product_name: "CSA Admin", language: "en", order_data: nil, certificate_builder: KeyChangeOrderData::CertificateBuilder.new, certificate_issued_at: Time.current.utc)
          @client = client
          @order_type = order_type.to_s.upcase
          @nonce = nonce
          @timestamp = timestamp
          @product_name = product_name
          @language = language
          @order_data = order_data || InitializationOrderData.new(
            client: client,
            order_type: order_type,
            certificate_builder: certificate_builder,
            certificate_issued_at: certificate_issued_at).to_xml
        end

        def to_xml = unsigned_xml

        def unsigned_xml
          ensure_supported_order_type!

          Nokogiri::XML::Builder.new do |xml|
            xml.ebicsUnsecuredRequest(DownloadRequest::ROOT_ATTRIBUTES) {
              xml.header(authenticate: true) {
                xml.static {
                  xml.HostID client.host_id
                  xml.Nonce nonce
                  xml.Timestamp timestamp
                  xml.PartnerID client.partner_id
                  xml.UserID client.user_id
                  xml.Product product_name, Language: language
                  order_details(xml)
                  xml.SecurityMedium "0000"
                }
                xml.mutable {
                  xml.TransactionPhase "Initialisation"
                }
              }
              body(xml)
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private

        attr_reader :client, :order_type, :nonce, :timestamp, :product_name, :language, :order_data

        def ensure_supported_order_type!
          return if SUPPORTED_ORDER_TYPES.include?(order_type)

          raise UnsupportedOperation, "EBICS onboarding request only supports #{SUPPORTED_ORDER_TYPES.to_sentence}"
        end

        def order_details(xml)
          xml.OrderDetails {
            xml.AdminOrderType order_type
            xml.StandardOrderParams
          }
        end

        def body(xml)
          xml.body {
            xml.DataTransfer {
              xml.OrderData Base64.strict_encode64(Zlib::Deflate.deflate(order_data))
            }
          }
        end
      end
    end
  end
end
