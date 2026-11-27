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
          blockAutomatedBrowsers: false,
          corsOrigins: [ "https://admin.acme.test", "https://members.acme.test" ],
          protocol: "sha256-pow"
        }.to_json)
      .to_return(status: 200, body: { siteKey: "site-key", secretKey: "secret-key" }.to_json)

    result = Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").create_key(
      name: "Acme (acme)",
      instrumentation: true,
      block_automated_browsers: false,
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
            blockAutomatedBrowsers: false,
            corsOrigins: [],
            protocol: "sha256-pow"
          }.to_json)
        .to_return(status: 200, body: { siteKey: "site-key", secretKey: "secret-key" }.to_json)

      result = Cap::Client.new(api_key: "api-key").create_key(
        name: "Acme (acme)",
        instrumentation: true,
        block_automated_browsers: false,
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
        block_automated_browsers: false,
        cors_origins: [])
    end

    assert_equal "Missing CAP_API_KEY or cap_api_key in credentials", error.message
  end

  test "lists site keys" do
    stub_request(:get, "https://cap.test/server/keys")
      .with(
        headers: {
          "Authorization" => "Bot api-key",
          "Content-Type" => "application/json"
        })
      .to_return(status: 200, body: [
        { siteKey: "site-key", name: "acme", secretOutdated: true }
      ].to_json)

    result = Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").keys

    assert_equal "site-key", result.first.fetch("siteKey")
    assert result.first.fetch("secretOutdated")
  end

  test "reads one site key, including stored protocol" do
    stub_request(:get, "https://cap.test/server/keys/site-key")
      .with(
        headers: {
          "Authorization" => "Bot api-key",
          "Content-Type" => "application/json"
        })
      .to_return(status: 200, body: {
        key: {
          siteKey: "site-key",
          name: "acme",
          config: { protocol: "sha256-pow", instrumentation: true }
        }
      }.to_json)

    result = Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").key("site-key")

    assert_equal "sha256-pow", result.dig("key", "config", "protocol")
  end

  test "rotates a site secret" do
    stub_request(:post, "https://cap.test/server/keys/site-key/rotate-secret")
      .with(
        headers: {
          "Authorization" => "Bot api-key",
          "Content-Type" => "application/json"
        })
      .to_return(status: 200, body: { secretKey: "rotated-secret" }.to_json)

    result = Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").rotate_secret("site-key")

    assert_equal "rotated-secret", result.fetch("secretKey")
  end

  test "pins sha256 without sending the rest of the config" do
    stub_request(:put, "https://cap.test/server/keys/site-key/config")
      .with(
        headers: {
          "Authorization" => "Bot api-key",
          "Content-Type" => "application/json"
        },
        body: { protocol: "sha256-pow" }.to_json)
      .to_return(status: 200, body: { success: true }.to_json)

    result = Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").pin_sha256("site-key")

    assert result.fetch("success")
  end

  test "deletes a site key" do
    stub_request(:delete, "https://cap.test/server/keys/site-key")
      .with(
        headers: {
          "Authorization" => "Bot api-key",
          "Content-Type" => "application/json"
        })
      .to_return(status: 200, body: { success: true }.to_json)

    result = Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").delete_key("site-key")

    assert result.fetch("success")
  end

  test "raises NotFoundError when deleting a missing site key" do
    stub_request(:delete, "https://cap.test/server/keys/missing-key")
      .to_return(status: 404, body: { success: false, error: "Key not found" }.to_json)

    error = assert_raises(Cap::Client::NotFoundError) do
      Cap::Client.new(api_url: "https://cap.test", api_key: "api-key").delete_key("missing-key")
    end

    assert_equal "Cap API request failed (404): Key not found", error.message
  end
end
