# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

module Billing
  class EBICS
    class KeyStore
      attr_reader :credentials, :keys, :url, :host_id, :user_id, :partner_id

      def initialize(credentials)
        @credentials = Credentials.new(credentials)
        @url = @credentials.url
        @host_id = @credentials.host_id
        @user_id = @credentials.participant_id
        @partner_id = @credentials.client_id
        @keys = load_keys
      end

      def a = keys.fetch("A006")
      def x = keys.fetch("X002")
      def e = keys.fetch("E002")
      def bank_x = keys.fetch("#{host_id.upcase}.X002")
      def bank_e = keys.fetch("#{host_id.upcase}.E002")

      def key_summary
        key_bits = keys.transform_values { |key| key.key.n.to_i.bit_length }
        participant_keys = key_bits.reject { |name, _bits| name.include?(".") }
        bank_keys = key_bits.select { |name, _bits| name.include?(".") }

        {
          "key_names" => key_bits.keys.sort,
          "key_bits" => key_bits.sort.to_h,
          "participant_key_min_bits" => participant_keys.values.min,
          "bank_key_min_bits" => bank_keys.values.min,
          "participant_key_versions" => participant_keys.keys.sort,
          "bank_key_versions" => bank_keys.keys.sort
        }
      end

      private

      def load_keys
        JSON.parse(credentials.keys).each_with_object({}) do |(name, encrypted_key), loaded|
          loaded[name.to_s] = Key.new(decrypt(encrypted_key)) if encrypted_key.present?
        end
      end

      def decrypt(encrypted_key)
        data = Base64.strict_decode64(encrypted_key)
        salt = data.byteslice(0, 8)
        encrypted_pem = data.byteslice(8, data.bytesize - 8)

        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.decrypt
        cipher.key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(credentials.secret, salt, 1, cipher.key_len)
        cipher.update(encrypted_pem) + cipher.final
      end
    end
  end
end
