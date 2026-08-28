# frozen_string_literal: true

require "test_helper"

class Cap::ClientTest < ActiveSupport::TestCase
  test "creates site key with bot API key" do
    stub_request(:post, "https://cap.test/server/keys")
      .with(
        headers: {
          "Authorization" => "Bot api-key",
          "Content-Type" => "application/json"
        },
        body: {
          name: "Acme (acme)",
          instrumentation: true,
          blockAutomatedBrowsers: true,
          corsOrigins: [ "https://admin.acme.test", "https://members.acme.test" ]
        }.to_json)
      .to_return(status: 200, body: { siteKey: "site-key", secretKey: "secret-key" }.to_json)

    result = Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").create_key(
      name: "Acme (acme)",
      instrumentation: true,
      block_automated_browsers: true,
      cors_origins: [ "https://admin.acme.test", "https://members.acme.test" ])

    assert_equal "site-key", result.fetch("siteKey")
    assert_equal "secret-key", result.fetch("secretKey")
  end

  test "uses the internal API URL by default" do
    with_env(
      "CAP_API_URL" => "https://cap.test",
      "CAP_INTERNAL_API_URL" => "http://cap.internal") do
      stub_request(:post, "http://cap.internal/server/keys")
        .with(
          headers: {
            "Authorization" => "Bot api-key",
            "Content-Type" => "application/json"
          },
          body: {
            name: "Acme (acme)",
            instrumentation: true,
            blockAutomatedBrowsers: true,
            corsOrigins: []
          }.to_json)
        .to_return(status: 200, body: { siteKey: "site-key", secretKey: "secret-key" }.to_json)

      result = Cap::Client.new(api_key: "api-key").create_key(
        name: "Acme (acme)",
        instrumentation: true,
        block_automated_browsers: true,
        cors_origins: [])

      assert_equal "site-key", result.fetch("siteKey")
    end
  end

  test "raises when API key is missing" do
    client = Cap::Client.new(api_url: "https://cap.test", api_key: nil)

    error = assert_raises(RuntimeError) do
      client.create_key(
        name: "Acme (acme)",
        instrumentation: true,
        block_automated_browsers: true,
        cors_origins: [])
    end

    assert_equal "Missing CAP_API_KEY or cap_api_key in credentials", error.message
  end
end
