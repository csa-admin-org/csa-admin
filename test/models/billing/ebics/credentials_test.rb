# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::CredentialsTest < ActiveSupport::TestCase
  test "normalizes string and symbol keys" do
    credentials = Billing::EBICS::Credentials.new(
      keys: "keys",
      "secret" => "secret",
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      participant_id: "PARTICIPANTID",
      client_id: "CLIENTID")

    assert_equal "keys", credentials.keys
    assert_equal "secret", credentials.secret
    assert_equal "https://ebics.example.test", credentials.url
    assert_equal "HOSTID", credentials.host_id
    assert_equal "PARTICIPANTID", credentials.participant_id
    assert_equal "CLIENTID", credentials.client_id
  end

  test "keeps current Epics client argument order" do
    credentials = Billing::EBICS::Credentials.new(ebics_credentials)

    assert_equal [
      "keys",
      "secret",
      "https://ebics.example.test",
      "HOSTID",
      "PARTICIPANTID",
      "CLIENTID"
    ], credentials.epics_client_args
  end

  test "exposes setup arguments without requiring finalized keys" do
    credentials = Billing::EBICS::Credentials.new(ebics_credentials.except("keys"))

    assert_equal [
      "secret",
      "https://ebics.example.test",
      "HOSTID",
      "PARTICIPANTID",
      "CLIENTID",
      2048
    ], credentials.epics_setup_args(2048)
  end

  private

  def ebics_credentials
    {
      "keys" => "keys",
      "secret" => "secret",
      "url" => "https://ebics.example.test",
      "host_id" => "HOSTID",
      "participant_id" => "PARTICIPANTID",
      "client_id" => "CLIENTID"
    }
  end
end
