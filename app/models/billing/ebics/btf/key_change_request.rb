# frozen_string_literal: true

require "nokogiri"
require "securerandom"

module Billing
  class EBICS
    module Btf
      class KeyChangeRequest
        attr_reader :payload

        def initialize(client:, target_client:, order_type: "HCS", nonce: SecureRandom.hex(16), timestamp: Time.current.utc.iso8601, product_name: "CSA Admin", language: "en", num_segments: 1, signer: nil, payload: nil)
          @client = client
          @target_client = target_client
          @order_type = order_type.to_s.upcase
          @nonce = nonce
          @timestamp = timestamp
          @product_name = product_name
          @language = language
          @num_segments = num_segments
          @signer = signer || RequestSigner.new(client)
          @payload = payload || UploadPayload.new(
            client: client,
            document: KeyChangeOrderData.new(client: target_client, order_type: order_type).to_xml)
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
                  xml.NumSegments num_segments
                }
                xml.mutable {
                  xml.TransactionPhase "Initialisation"
                }
              }
              DownloadRequest.auth_signature(xml)
              body(xml)
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private

        attr_reader :client, :target_client, :order_type, :nonce, :timestamp, :product_name, :language, :num_segments, :signer

        def ensure_supported_order_type!
          return if order_type == "HCS"

          raise UnsupportedOperation, "EBICS key rotation only supports HCS for replacing all subscriber keys"
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

        def body(xml)
          xml.body {
            xml.DataTransfer {
              data_encryption_info(xml)
              xml.SignatureData payload.encrypted_signature_data, authenticate: true
              xml.DataDigest payload.data_digest, SignatureVersion: payload.signature_version
            }
          }
        end

        def data_encryption_info(xml)
          xml.DataEncryptionInfo(authenticate: true) {
            xml.EncryptionPubKeyDigest client.bank_e.public_digest,
              Version: "E002",
              Algorithm: DownloadRequest::SHA256_ALGORITHM
            xml.TransactionKey payload.encrypted_transaction_key
          }
        end
      end
    end
  end
end
