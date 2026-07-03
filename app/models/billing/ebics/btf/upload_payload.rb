# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"
require "securerandom"
require "zlib"

module Billing
  class EBICS
    module Btf
      class UploadPayload
        SIGNATURE_NAMESPACE = "http://www.ebics.org/S002"
        SIGNATURE_SCHEMA_LOCATION = "#{SIGNATURE_NAMESPACE} #{SIGNATURE_NAMESPACE}/ebics_signature.xsd"
        SIGNATURE_VERSION = "A006"

        attr_reader :transaction_key, :signature_version

        def initialize(client:, document:, transaction_key: random_transaction_key, signature_version: SIGNATURE_VERSION)
          @client = client
          @document = document.to_s
          @transaction_key = transaction_key
          @signature_version = signature_version
        end

        def encrypted_transaction_key
          Base64.strict_encode64(client.bank_e.key.public_encrypt(transaction_key))
        end

        def encrypted_signature_data
          encrypt_and_encode(Zlib::Deflate.deflate(order_signature_xml))
        end

        def encrypted_order_data
          encrypt_and_encode(Zlib::Deflate.deflate(document))
        end

        def data_digest
          Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(signable_document))
        end

        def order_signature_xml
          Nokogiri::XML::Builder.new do |xml|
            xml.UserSignatureData("xmlns" => SIGNATURE_NAMESPACE,
              "xmlns:xsi" => DownloadRequest::XSI_NAMESPACE,
              "xsi:schemaLocation" => SIGNATURE_SCHEMA_LOCATION) {
              xml.OrderSignatureData {
                xml.SignatureVersion signature_version
                xml.SignatureValue signature_value
                xml.PartnerID client.partner_id
                xml.UserID client.user_id
              }
            }
          end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
        end

        private

        attr_reader :client, :document

        def self.random_transaction_key
          cipher = OpenSSL::Cipher.new("aes-128-cbc")
          cipher.encrypt
          cipher.random_key
        end

        def random_transaction_key
          self.class.random_transaction_key
        end

        def signature_value
          client.a.sign(OpenSSL::Digest::SHA256.digest(signable_document))
        end

        def signable_document
          document.gsub(/\n|\r/, "")
        end

        def encrypt_and_encode(data)
          Base64.strict_encode64(encrypt(data))
        end

        def encrypt(data)
          cipher = OpenSSL::Cipher.new("aes-128-cbc")
          cipher.encrypt
          cipher.padding = 0
          cipher.key = transaction_key
          cipher.iv = "\0" * cipher.iv_len
          cipher.update(pad(data, cipher.block_size)) + cipher.final
        end

        def pad(data, block_size)
          length = block_size * ((data.bytesize / block_size) + 1)
          padding_size = length - data.bytesize
          data.ljust(length, "\0").tap { |padded| padded[-1] = padding_size.chr }
        end
      end
    end
  end
end
