# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"

module Billing
  class EBICS
    module Btf
      class InitializationOrderData
        SUPPORTED_ORDER_TYPES = %w[INI HIA].freeze
        SIGNATURE_NAMESPACE = UploadPayload::SIGNATURE_NAMESPACE

        def initialize(client:, order_type:, certificate_builder: KeyChangeOrderData::CertificateBuilder.new, certificate_issued_at: Time.current.utc)
          @client = client
          @order_type = order_type.to_s.upcase
          @certificate_builder = certificate_builder
          @certificate_issued_at = certificate_issued_at.to_time.utc
        end

        def to_xml
          ensure_supported_order_type!

          order_type == "INI" ? ini_xml : hia_xml
        end

        def certificates
          versions.index_with { |version| certificate_for(version) }
        end

        private

        attr_reader :client, :order_type, :certificate_builder, :certificate_issued_at

        def ensure_supported_order_type!
          return if SUPPORTED_ORDER_TYPES.include?(order_type)

          raise UnsupportedOperation, "EBICS onboarding only supports #{SUPPORTED_ORDER_TYPES.to_sentence}"
        end

        def ini_xml
          Nokogiri::XML::Builder.new do |xml|
            xml.SignaturePubKeyOrderData(root_attributes) {
              xml.SignaturePubKeyInfo {
                public_key_info(xml, client.a.key, "A006", timestamp: true)
                xml.SignatureVersion "A006"
              }
              xml.PartnerID client.partner_id
              xml.UserID client.user_id
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        def hia_xml
          Nokogiri::XML::Builder.new do |xml|
            xml.HIARequestOrderData(root_attributes) {
              xml.AuthenticationPubKeyInfo {
                public_key_info(xml, client.x.key, "X002")
                xml.AuthenticationVersion "X002"
              }
              xml.EncryptionPubKeyInfo {
                public_key_info(xml, client.e.key, "E002")
                xml.EncryptionVersion "E002"
              }
              xml.PartnerID client.partner_id
              xml.UserID client.user_id
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        def root_attributes
          {
            "xmlns" => DownloadRequest::H005_NAMESPACE,
            "xmlns:ds" => DownloadRequest::XMLDSIG_NAMESPACE,
            "xmlns:esig" => SIGNATURE_NAMESPACE
          }
        end

        def public_key_info(xml, key, version, timestamp: false)
          x509_data(xml, key, version)
          pub_key_value(xml, key) do
            xml.TimeStamp certificate_issued_at.iso8601 if timestamp
          end
        end

        def x509_data(xml, key, version)
          certificate = certificate_builder.certificate_for(
            key,
            version: version,
            client: client,
            now: certificate_issued_at)

          xml["ds"].X509Data {
            xml["ds"].X509IssuerSerial {
              xml["ds"].X509IssuerName certificate.issuer.to_s
              xml["ds"].X509SerialNumber certificate.serial
            }
            xml["ds"].X509Certificate Base64.strict_encode64(certificate.to_der)
          }
        end

        def pub_key_value(xml, key)
          xml.PubKeyValue {
            xml["ds"].RSAKeyValue {
              xml["ds"].Modulus crypto_binary(key.n)
              xml["ds"].Exponent crypto_binary(key.e)
            }
            yield if block_given?
          }
        end

        def certificate_for(version)
          key = {
            "A006" => client.a.key,
            "X002" => client.x.key,
            "E002" => client.e.key
          }.fetch(version)

          certificate_builder.certificate_for(
            key,
            version: version,
            client: client,
            now: certificate_issued_at)
        end

        def versions
          order_type == "INI" ? %w[A006] : %w[X002 E002]
        end

        def crypto_binary(value)
          hex = value.to_i.to_s(16)
          hex = "0#{hex}" if hex.length.odd?
          Base64.strict_encode64([ hex ].pack("H*"))
        end
      end
    end
  end
end
