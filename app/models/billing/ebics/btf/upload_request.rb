# frozen_string_literal: true

require "nokogiri"
require "securerandom"

module Billing
  class EBICS
    module Btf
      class UploadRequest
        def initialize(client:, operation:, document:, nonce: SecureRandom.hex(16), timestamp: Time.current.utc.iso8601, product_name: "CSA Admin", language: "en", num_segments: 1, signer: nil, payload: nil)
          @client = client
          @operation = operation
          @nonce = nonce
          @timestamp = timestamp
          @product_name = product_name
          @language = language
          @num_segments = num_segments
          @signer = signer || RequestSigner.new(client)
          @payload = payload || UploadPayload.new(client: client, document: document)
        end

        def to_xml
          signer.sign(unsigned_xml)
        end

        def unsigned_xml
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

        attr_reader :payload

        private
          attr_reader :client, :operation, :nonce, :timestamp, :product_name, :language, :num_segments, :signer

          def order_details(xml)
            xml.OrderDetails {
              xml.AdminOrderType btf.fetch("order_type")
              btu_order_params(xml)
            }
          end

          def btu_order_params(xml)
            xml.BTUOrderParams(btu_order_params_attributes) {
              service(xml)
              xml.SignatureFlag if signature_flag?
            }
          end

          def btu_order_params_attributes
            {}.tap do |attributes|
              attributes[:fileName] = btf.fetch("file_name") if btf["file_name"].present?
            end
          end

          def service(xml)
            xml.Service {
              xml.ServiceName btf.fetch("service_name")
              xml.Scope btf.fetch("scope") if btf["scope"].present?
              xml.ServiceOption btf.fetch("service_option") if btf["service_option"].present?
              xml.Container containerType: btf.fetch("container") if btf["container"].present?
              msg_name(xml)
            }
          end

          def msg_name(xml)
            if btf["version"].present?
              xml.MsgName btf.fetch("message_name"), version: btf.fetch("version")
            else
              xml.MsgName btf.fetch("message_name")
            end
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

          def signature_flag?
            return true unless btf.key?("signature_flag")

            ActiveModel::Type::Boolean.new.cast(btf["signature_flag"])
          end

          def btf
            @btf ||= operation.btf.fetch_values(
              "order_type",
              "service_name",
              "message_name").then { operation.btf }
          end
      end
    end
  end
end
