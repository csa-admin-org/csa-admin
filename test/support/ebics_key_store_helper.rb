# frozen_string_literal: true

require "base64"
require "openssl"
require "securerandom"

module EbicsKeyStoreHelper
  def synthetic_ebics_key_material(host_id: "HOSTID", keysize: 2048, bank_x: OpenSSL::PKey::RSA.generate(keysize), bank_e: OpenSSL::PKey::RSA.generate(keysize))
    {
      "A006" => OpenSSL::PKey::RSA.generate(keysize),
      "X002" => OpenSSL::PKey::RSA.generate(keysize),
      "E002" => OpenSSL::PKey::RSA.generate(keysize),
      "#{host_id.upcase}.X002" => OpenSSL::PKey::RSA.new(bank_x.public_to_pem),
      "#{host_id.upcase}.E002" => OpenSSL::PKey::RSA.new(bank_e.public_to_pem)
    }
  end

  def synthetic_ebics_credentials(secret: "secret", url: "https://ebics.example.test", host_id: "HOSTID", user_id: "USERID", partner_id: "PARTNERID", keysize: 2048, bank_x: OpenSSL::PKey::RSA.generate(keysize), bank_e: OpenSSL::PKey::RSA.generate(keysize), key_material: nil)
    key_material ||= synthetic_ebics_key_material(
      host_id: host_id,
      keysize: keysize,
      bank_x: bank_x,
      bank_e: bank_e)

    {
      "keys" => encrypted_ebics_keys(key_material, secret),
      "secret" => secret,
      "url" => url,
      "host_id" => host_id,
      "participant_id" => user_id,
      "client_id" => partner_id
    }
  end

  private

  def encrypted_ebics_keys(keys, secret)
    keys.transform_values { |key| encrypt_ebics_key(key, secret) }.to_json
  end

  def encrypt_ebics_key(key, secret)
    salt = SecureRandom.random_bytes(8)
    cipher = OpenSSL::Cipher.new("aes-256-cbc")
    cipher.encrypt
    cipher.key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(secret, salt, 1, cipher.key_len)

    Base64.strict_encode64(salt + cipher.update(key.to_pem) + cipher.final)
  end
end
