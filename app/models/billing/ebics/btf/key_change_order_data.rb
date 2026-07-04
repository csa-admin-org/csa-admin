# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"

module Billing
  class EBICS
    module Btf
      class KeyChangeOrderData
        SIGNATURE_NAMESPACE = UploadPayload::SIGNATURE_NAMESPACE

        def initialize(client:, order_type: "HCS", certificate_builder: CertificateBuilder.new)
          @client = client
          @order_type = order_type.to_s.upcase
          @certificate_builder = certificate_builder
        end

        def to_xml
          ensure_supported_order_type!

          Nokogiri::XML::Builder.new do |xml|
            xml.HCSRequestOrderData(root_attributes) {
              authentication_pub_key_info(xml)
              encryption_pub_key_info(xml)
              signature_pub_key_info(xml)
              xml.PartnerID client.partner_id
              xml.UserID client.user_id
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private

        attr_reader :client, :order_type, :certificate_builder

        def ensure_supported_order_type!
          return if order_type == "HCS"

          raise UnsupportedOperation, "EBICS key rotation only supports HCS for replacing all subscriber keys"
        end

        def root_attributes
          {
            "xmlns" => DownloadRequest::H005_NAMESPACE,
            "xmlns:ds" => DownloadRequest::XMLDSIG_NAMESPACE,
            "xmlns:esig" => SIGNATURE_NAMESPACE
          }
        end

        def authentication_pub_key_info(xml)
          xml.AuthenticationPubKeyInfo {
            public_key_info(xml, client.x.key, "X002")
            xml.AuthenticationVersion "X002"
          }
        end

        def encryption_pub_key_info(xml)
          xml.EncryptionPubKeyInfo {
            public_key_info(xml, client.e.key, "E002")
            xml.EncryptionVersion "E002"
          }
        end

        def signature_pub_key_info(xml)
          xml["esig"].SignaturePubKeyInfo {
            public_key_info(xml, client.a.key, "A006")
            xml["esig"].SignatureVersion "A006"
          }
        end

        def public_key_info(xml, key, version)
          x509_data(xml, key, version)
          key_value(xml, key)
        end

        def x509_data(xml, key, version)
          certificate = certificate_builder.certificate_for(key, version: version, client: client)

          xml["ds"].X509Data {
            xml["ds"].X509IssuerSerial {
              xml["ds"].X509IssuerName certificate.issuer.to_s
              xml["ds"].X509SerialNumber certificate.serial
            }
            xml["ds"].X509Certificate Base64.strict_encode64(certificate.to_der)
          }
        end

        def key_value(xml, key)
          xml["ds"].KeyValue {
            xml["ds"].RSAKeyValue {
              xml["ds"].Modulus crypto_binary(key.n)
              xml["ds"].Exponent crypto_binary(key.e)
            }
          }
        end

        def crypto_binary(value)
          hex = value.to_i.to_s(16)
          hex = "0#{hex}" if hex.length.odd?
          Base64.strict_encode64([ hex ].pack("H*"))
        end

        class CertificateBuilder
          def certificate_for(key, version:, client:, now: Time.current.utc)
            OpenSSL::X509::Certificate.new.tap do |certificate|
              certificate.version = 2
              certificate.serial = serial_for(key, version)
              certificate.subject = subject_for(client, version)
              certificate.issuer = certificate.subject
              certificate.public_key = key.public_key
              certificate.not_before = now - 1.minute
              certificate.not_after = now + 10.years
              certificate.sign(key, OpenSSL::Digest::SHA256.new)
            end
          end

          private

          def serial_for(key, version)
            OpenSSL::BN.new(OpenSSL::Digest::SHA256.hexdigest("#{version}:#{key.n}:#{key.e}")[0, 32], 16).to_i
          end

          def subject_for(client, version)
            OpenSSL::X509::Name.new([
              [ "CN", "#{client.user_id} #{version}" ],
              [ "OU", client.partner_id.to_s ],
              [ "O", "CSA Admin EBICS" ]
            ])
          end
        end
      end
    end
  end
end
