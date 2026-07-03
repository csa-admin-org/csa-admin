# frozen_string_literal: true

require "test_helper"
require "base64"
require "openssl"

class Billing::EBICS::KeyStoreTest < ActiveSupport::TestCase
  test "loads encrypted EBICS key blobs" do
    key_material = synthetic_ebics_key_material
    store = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(key_material: key_material))

    assert_equal digest_for(key_material.fetch("A006")), store.a.public_digest
    assert_equal digest_for(key_material.fetch("X002")), store.x.public_digest
    assert_equal digest_for(key_material.fetch("E002")), store.e.public_digest
    assert_equal digest_for(key_material.fetch("HOSTID.X002")), store.bank_x.public_digest
    assert_equal digest_for(key_material.fetch("HOSTID.E002")), store.bank_e.public_digest
  end

  test "exposes the current EBICS client identity mapping" do
    store = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(
      host_id: "HOSTID",
      user_id: "USERID",
      partner_id: "PARTNERID"))

    assert_equal "HOSTID", store.host_id
    assert_equal "USERID", store.user_id
    assert_equal "PARTNERID", store.partner_id
  end

  test "summarizes participant and bank keys" do
    store = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials)
    summary = store.key_summary

    assert_equal %w[A006 E002 HOSTID.E002 HOSTID.X002 X002], summary.fetch("key_names")
    assert_equal %w[A006 E002 X002], summary.fetch("participant_key_versions")
    assert_equal %w[HOSTID.E002 HOSTID.X002], summary.fetch("bank_key_versions")
    assert_operator summary.fetch("participant_key_min_bits"), :>=, 2048
    assert_operator summary.fetch("bank_key_min_bits"), :>=, 2048
  end

  test "uses public-only bank keys for encryption and signature verification" do
    bank_x = OpenSSL::PKey::RSA.generate(2048)
    bank_e = OpenSSL::PKey::RSA.generate(2048)
    store = Billing::EBICS::KeyStore.new(credentials_with_bank_keys(bank_x: bank_x, bank_e: bank_e))
    message = "signed bank response"
    signature = bank_x.sign(OpenSSL::Digest::SHA256.new, message)

    assert_not store.bank_x.key.private?
    assert_not store.bank_e.key.private?
    assert store.bank_x.key.verify(OpenSSL::Digest::SHA256.new, signature, message)
    assert_equal "1234567890abcdef", bank_e.private_decrypt(store.bank_e.key.public_encrypt("1234567890abcdef"))
  end

  test "signs order data with the participant signature key" do
    store = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials)
    digest = OpenSSL::Digest::SHA256.digest("document")

    signature = Base64.strict_decode64(store.a.sign(digest))

    assert store.a.key.verify_pss(
      "SHA256",
      signature,
      digest,
      salt_length: :digest,
      mgf1_hash: "SHA256")
  end

  private

  def credentials_with_bank_keys(bank_x:, bank_e:)
    synthetic_ebics_credentials(bank_x: bank_x, bank_e: bank_e)
  end

  def digest_for(key)
    Billing::EBICS::Key.new(key).public_digest
  end
end
