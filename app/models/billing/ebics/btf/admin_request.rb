# frozen_string_literal: true

require "nokogiri"
require "securerandom"

module Billing
  class EBICS
    module Btf
      class AdminRequest
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

          Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(DownloadRequest::ROOT_ATTRIBUTES) {
              xml.header(authenticate: true) {
                xml.static {
                  xml.HostID client.host_id
                  xml.Nonce nonce
                  xml.Timestamp timestamp
                  xml.PartnerID client.partner_id
                  xml.UserID client.user_id
                  xml.Product product_name, Language: language
                  order_details(xml)
                  bank_public_key_digests(xml)
                  xml.SecurityMedium "0000"
                }
                xml.mutable {
                  xml.TransactionPhase "Initialisation"
                }
              }
              DownloadRequest.auth_signature(xml)
              xml.body
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
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

          def bank_public_key_digests(xml)
            xml.BankPubKeyDigests {
              xml.Authentication client.bank_x.public_digest,
                Version: "X002",
                Algorithm: DownloadRequest::SHA256_ALGORITHM
              xml.Encryption client.bank_e.public_digest,
                Version: "E002",
                Algorithm: DownloadRequest::SHA256_ALGORITHM
            }
          end
      end
    end
  end
end
