# frozen_string_literal: true

require "test_helper"

class Cap::VerifierTest < ActiveSupport::TestCase
  test "verifies token through siteverify" do
    Current.org.update!(cap_site_key: "site-key", cap_secret_key: "secret-key")

    with_env("CAP_SKIP_VERIFY" => nil, "CAP_API_URL" => "https://cap.test") do
      stub_request(:post, "https://cap.test/site-key/siteverify")
        .with(
          headers: { "Content-Type" => "application/json" },
          body: { secret: "secret-key", response: "cap-token" }.to_json)
        .to_return(status: 200, body: { success: true }.to_json)

      assert Cap::Verifier.new(Current.org, "cap-token").verify
    end
  end

  test "returns false when Cap rejects token" do
    Current.org.update!(cap_site_key: "site-key", cap_secret_key: "secret-key")

    with_env("CAP_SKIP_VERIFY" => nil, "CAP_API_URL" => "https://cap.test") do
      stub_request(:post, "https://cap.test/site-key/siteverify")
        .to_return(status: 200, body: { success: false }.to_json)

      assert_not Cap::Verifier.new(Current.org, "cap-token").verify
    end
  end

  test "uses development keys when configured" do
    Current.org.update!(cap_site_key: "tenant-site-key", cap_secret_key: "tenant-secret-key")

    with_env(
      "CAP_SKIP_VERIFY" => nil,
      "CAP_API_URL" => "https://cap.test",
      "CAP_DEVELOPMENT_SITE_KEY" => "development-site-key",
      "CAP_DEVELOPMENT_SECRET_KEY" => "development-secret-key") do
      with_rails_env("development") do
        stub_request(:post, "https://cap.test/development-site-key/siteverify")
          .with(body: { secret: "development-secret-key", response: "cap-token" }.to_json)
          .to_return(status: 200, body: { success: true }.to_json)

        assert Cap::Verifier.new(Current.org, "cap-token").verify
      end
    end
  end

  test "returns false outside production when tenant keys are missing" do
    Current.org.update!(cap_site_key: nil, cap_secret_key: nil)

    with_env("CAP_SKIP_VERIFY" => nil) do
      assert_not Cap::Verifier.new(Current.org, "cap-token").verify
    end
  end
end
