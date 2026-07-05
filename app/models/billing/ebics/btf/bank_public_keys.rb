# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"

module Billing
  class EBICS
    module Btf
      class BankPublicKeys
        KEY_INFOS = {
          "X002" => [ "AuthenticationPubKeyInfo", "AuthenticationVersion" ],
          "E002" => [ "EncryptionPubKeyInfo", "EncryptionVersion" ]
        }.freeze

        def initialize(host_id:, order_data:)
          @host_id = host_id.to_s.upcase
          @doc = Nokogiri::XML(order_data.to_s)
        end

        def keys
          @keys ||= begin
            validate_document!
            KEY_INFOS.each_with_object({}) do |(version, (node_name, version_node_name)), values|
              values["#{host_id}.#{version}"] = public_key_from(version, node_name, version_node_name)
            end
          end
        end

        def metadata
          keys.transform_values do |key|
            wrapped = Key.new(key)
            {
              "role" => "bank",
              "bits" => wrapped.bits,
              "public_digest" => wrapped.public_digest
            }
          end
        end

        def to_h
          {
            "key_versions" => keys.keys.sort,
            "keys" => metadata
          }
        end

        private

        attr_reader :host_id, :doc

        def validate_document!
          unless doc.root&.name == "HPBResponseOrderData" && doc.root.namespace&.href == DownloadRequest::H005_NAMESPACE
            raise UnsupportedOperation, "HPB response order data is not H005 HPBResponseOrderData"
          end
        end

        def public_key_from(version, node_name, version_node_name)
          node = doc.at_xpath("//*[local-name()='#{node_name}']") ||
            raise(UnsupportedOperation, "HPB response is missing #{node_name}")
          received_version = node.at_xpath(".//*[local-name()='#{version_node_name}']")&.text
          raise UnsupportedOperation, "HPB response #{node_name} must use #{version}" unless received_version == version

          certificate_key(node) || rsa_key_value(node) ||
            raise(UnsupportedOperation, "HPB response #{node_name} does not contain a public key")
        end

        def certificate_key(node)
          certificate = node.at_xpath(".//*[local-name()='X509Certificate']")
          return unless certificate&.text&.present?

          OpenSSL::X509::Certificate.new(Base64.strict_decode64(strip_whitespace(certificate.text))).public_key
        end

        def rsa_key_value(node)
          rsa = node.at_xpath(".//*[local-name()='RSAKeyValue']")
          return unless rsa

          modulus = crypto_binary(rsa, "Modulus")
          exponent = crypto_binary(rsa, "Exponent")
          sequence = OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(modulus, 2)),
            OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(exponent, 2))
          ])
          OpenSSL::PKey::RSA.new(sequence.to_der)
        end

        def crypto_binary(node, name)
          value = node.at_xpath(".//*[local-name()='#{name}']")&.text
          raise UnsupportedOperation, "HPB response RSA key is missing #{name}" if value.blank?

          Base64.strict_decode64(strip_whitespace(value))
        end

        def strip_whitespace(value)
          value.to_s.gsub(/\s+/, "")
        end
      end
    end
  end
end
