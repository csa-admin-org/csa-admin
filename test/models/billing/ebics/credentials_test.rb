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
