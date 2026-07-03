# frozen_string_literal: true

require "epics"
require "openssl"

module EbicsKeyStoreHelper
  def synthetic_epics_client(secret: "secret", url: "https://ebics.example.test", host_id: "HOSTID", user_id: "USERID", partner_id: "PARTNERID", keysize: 2048, bank_x: OpenSSL::PKey::RSA.generate(keysize), bank_e: OpenSSL::PKey::RSA.generate(keysize))
    ::Epics::Client.setup(secret, url, host_id, user_id, partner_id, keysize).tap do |client|
      client.keys["#{host_id.upcase}.X002"] = ::Epics::Key.new(bank_x.public_to_pem)
      client.keys["#{host_id.upcase}.E002"] = ::Epics::Key.new(bank_e.public_to_pem)
    end
  end

  def synthetic_ebics_credentials(secret: "secret", url: "https://ebics.example.test", host_id: "HOSTID", user_id: "USERID", partner_id: "PARTNERID", keysize: 2048, bank_x: OpenSSL::PKey::RSA.generate(keysize), bank_e: OpenSSL::PKey::RSA.generate(keysize))
    client = synthetic_epics_client(
      secret: secret,
      url: url,
      host_id: host_id,
      user_id: user_id,
      partner_id: partner_id,
      keysize: keysize,
      bank_x: bank_x,
      bank_e: bank_e)

    {
      "keys" => client.send(:dump_keys),
      "secret" => secret,
      "url" => url,
      "host_id" => host_id,
      "participant_id" => user_id,
      "client_id" => partner_id
    }
  end
end
