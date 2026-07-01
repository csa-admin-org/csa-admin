# frozen_string_literal: true

require "nokogiri"
require "securerandom"

module Billing
  class EBICS
    module Btf
      class DownloadRequest
        H005_NAMESPACE = "urn:org:ebics:H005"
        XMLDSIG_NAMESPACE = "http://www.w3.org/2000/09/xmldsig#"
        XSI_NAMESPACE = "http://www.w3.org/2001/XMLSchema-instance"
        SCHEMA_LOCATION = "#{H005_NAMESPACE} ebics_request_H005.xsd"
        SHA256_ALGORITHM = "http://www.w3.org/2001/04/xmlenc#sha256"
        XML_C14N_ALGORITHM = "http://www.w3.org/TR/2001/REC-xml-c14n-20010315"
        RSA_SHA256_ALGORITHM = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"

        def initialize(client:, operation:, from:, to:, nonce: SecureRandom.hex(16), timestamp: Time.current.utc.iso8601, product_name: "CSA Admin", language: "en", signer: nil)
          @client = client
          @operation = operation
          @from = from
          @to = to
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
          Nokogiri::XML::Builder.new do |xml|
            xml.ebicsRequest(root_attributes) {
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
              auth_signature(xml)
              xml.body
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private
          attr_reader :client, :operation, :from, :to, :nonce, :timestamp, :product_name, :language, :signer

          def root_attributes
            {
              "xmlns" => H005_NAMESPACE,
              "xmlns:ds" => XMLDSIG_NAMESPACE,
              "xmlns:xsi" => XSI_NAMESPACE,
              "xsi:schemaLocation" => SCHEMA_LOCATION,
              "Version" => "H005",
              "Revision" => "1"
            }
          end

          def order_details(xml)
            xml.OrderDetails {
              xml.AdminOrderType btf.fetch("order_type")
              xml.BTDOrderParams {
                service(xml)
                date_range(xml)
              }
            }
          end

          def service(xml)
            xml.Service {
              xml.ServiceName btf.fetch("service_name")
              xml.Scope btf.fetch("scope")
              xml.ServiceOption btf.fetch("service_option") if btf["service_option"].present?
              xml.Container containerType: btf.fetch("container")
              xml.MsgName btf.fetch("message_name"), version: btf.fetch("version")
            }
          end

          def date_range(xml)
            return if from.blank? || to.blank?

            xml.DateRange {
              xml.Start format_date(from)
              xml.End format_date(to)
            }
          end

          def bank_public_key_digests(xml)
            xml.BankPubKeyDigests {
              xml.Authentication client.bank_x.public_digest,
                Version: "X002",
                Algorithm: SHA256_ALGORITHM
              xml.Encryption client.bank_e.public_digest,
                Version: "E002",
                Algorithm: SHA256_ALGORITHM
            }
          end

          def auth_signature(xml)
            xml.AuthSignature {
              xml["ds"].SignedInfo {
                xml["ds"].CanonicalizationMethod Algorithm: XML_C14N_ALGORITHM
                xml["ds"].SignatureMethod Algorithm: RSA_SHA256_ALGORITHM
                xml["ds"].Reference URI: "#xpointer(//*[@authenticate='true'])" do
                  xml["ds"].Transforms {
                    xml["ds"].Transform Algorithm: XML_C14N_ALGORITHM
                  }
                  xml["ds"].DigestMethod Algorithm: SHA256_ALGORITHM
                  xml["ds"].DigestValue
                end
              }
              xml["ds"].SignatureValue
            }
          end

          def btf
            @btf ||= operation.btf.fetch_values(
              "order_type",
              "service_name",
              "scope",
              "container",
              "message_name",
              "version").then { operation.btf }
          end

          def format_date(value)
            value.respond_to?(:to_date) ? value.to_date.iso8601 : value.to_s
          end
      end
    end
  end
end
