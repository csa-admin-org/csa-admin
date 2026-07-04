# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "securerandom"

module Billing
  class EBICS
    class KeyStore
      attr_reader :credentials, :keys, :url, :host_id, :user_id, :partner_id

      def self.encrypt_keys(keys, secret)
        keys.transform_values { |key| encrypt_key(key, secret) }.to_json
      end

      def self.encrypt_key(key, secret)
        salt = SecureRandom.random_bytes(8)
        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.encrypt
        cipher.key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(secret, salt, 1, cipher.key_len)

        Base64.strict_encode64(salt + cipher.update(key.to_pem) + cipher.final)
      end

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
        key_bits = keys.transform_values(&:bits)
        participant_keys = key_bits.reject { |name, _bits| bank_key?(name) }
        bank_keys = key_bits.select { |name, _bits| bank_key?(name) }

        {
          "key_names" => key_bits.keys.sort,
          "key_bits" => key_bits.sort.to_h,
          "participant_key_min_bits" => participant_keys.values.min,
          "bank_key_min_bits" => bank_keys.values.min,
          "participant_key_versions" => participant_keys.keys.sort,
          "bank_key_versions" => bank_keys.keys.sort
        }
      end

      def key_metadata
        keys.keys.sort.index_with do |name|
          key = keys.fetch(name)
          {
            "role" => bank_key?(name) ? "bank" : "participant",
            "bits" => key.bits,
            "public_digest" => key.public_digest
          }
        end
      end

      def bank_key_material
        keys.slice("#{host_id.upcase}.X002", "#{host_id.upcase}.E002")
          .transform_values(&:key)
      end

      private

      def bank_key?(name)
        name.to_s.include?(".")
      end

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
