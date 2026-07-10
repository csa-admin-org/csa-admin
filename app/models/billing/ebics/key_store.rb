# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "securerandom"

module Billing
  class EBICS
    class KeyStore
      InvalidKeyBlob = Class.new(StandardError)
      KEY_BLOB_VERSION = 2
      KEY_BLOB_CIPHER = "aes-256-gcm"
      KEY_BLOB_KDF = "pbkdf2_hmac_sha256"
      KEY_BLOB_ITERATIONS = 20_000
      KEY_BLOB_SALT_BYTES = 16
      KEY_BLOB_IV_BYTES = 12

      attr_reader :credentials, :keys, :url, :host_id, :user_id, :partner_id

      def self.encrypt_keys(keys, secret)
        keys.transform_values { |key| encrypt_key(key, secret) }.to_json
      end

      def self.encrypt_key(key, secret)
        salt = SecureRandom.random_bytes(KEY_BLOB_SALT_BYTES)
        iv = SecureRandom.random_bytes(KEY_BLOB_IV_BYTES)
        cipher = OpenSSL::Cipher.new(KEY_BLOB_CIPHER)
        cipher.encrypt
        cipher.key = derive_key(secret, salt, KEY_BLOB_ITERATIONS, cipher.key_len)
        cipher.iv = iv
        cipher.auth_data = ""
        ciphertext = cipher.update(key.to_pem) + cipher.final

        {
          "version" => KEY_BLOB_VERSION,
          "cipher" => KEY_BLOB_CIPHER,
          "kdf" => KEY_BLOB_KDF,
          "iterations" => KEY_BLOB_ITERATIONS,
          "salt" => Base64.strict_encode64(salt),
          "iv" => Base64.strict_encode64(iv),
          "auth_tag" => Base64.strict_encode64(cipher.auth_tag),
          "ciphertext" => Base64.strict_encode64(ciphertext)
        }
      end

      def self.derive_key(secret, salt, iterations, length)
        OpenSSL::PKCS5.pbkdf2_hmac(secret, salt, iterations, length, OpenSSL::Digest::SHA256.new)
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
        KeyMetadata.for_keys(keys.transform_values(&:key))
      end

      def bank_key_material
        keys.slice("#{host_id.upcase}.X002", "#{host_id.upcase}.E002")
          .transform_values(&:key)
      end

      private

      def bank_key?(name)
        KeyMetadata.bank_key?(name)
      end

      def load_keys
        JSON.parse(credentials.keys).each_with_object({}) do |(name, encrypted_key), loaded|
          loaded[name.to_s] = Key.new(decrypt(encrypted_key)) if encrypted_key.present?
        end
      end

      def decrypt(encrypted_key)
        case encrypted_key
        when String
          decrypt_legacy(encrypted_key)
        when Hash
          decrypt_versioned(encrypted_key)
        else
          raise InvalidKeyBlob, "Unsupported EBICS key blob"
        end
      end

      def decrypt_legacy(encrypted_key)
        data = Base64.strict_decode64(encrypted_key)
        salt = data.byteslice(0, 8)
        encrypted_pem = data.byteslice(8, data.bytesize - 8)

        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.decrypt
        cipher.key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(credentials.secret, salt, 1, cipher.key_len)
        cipher.update(encrypted_pem) + cipher.final
      end

      def decrypt_versioned(encrypted_key)
        blob = encrypted_key.deep_stringify_keys
        raise InvalidKeyBlob, "Unsupported EBICS key blob version" unless blob["version"] == KEY_BLOB_VERSION
        raise InvalidKeyBlob, "Unsupported EBICS key cipher" unless blob["cipher"] == KEY_BLOB_CIPHER
        raise InvalidKeyBlob, "Unsupported EBICS key derivation" unless blob["kdf"] == KEY_BLOB_KDF

        cipher = OpenSSL::Cipher.new(KEY_BLOB_CIPHER)
        cipher.decrypt
        cipher.key = self.class.derive_key(
          credentials.secret,
          strict_base64(blob.fetch("salt")),
          blob.fetch("iterations").to_i,
          cipher.key_len)
        cipher.iv = strict_base64(blob.fetch("iv"))
        cipher.auth_tag = strict_base64(blob.fetch("auth_tag"))
        cipher.auth_data = ""
        cipher.update(strict_base64(blob.fetch("ciphertext"))) + cipher.final
      rescue KeyError, ArgumentError, OpenSSL::OpenSSLError => e
        raise InvalidKeyBlob, e.message
      end

      def strict_base64(value)
        Base64.strict_decode64(value.to_s)
      end
    end
  end
end
