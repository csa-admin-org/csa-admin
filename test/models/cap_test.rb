# frozen_string_literal: true

require "test_helper"

class CapTest < ActiveSupport::TestCase
  test "uses development keys in development" do
    Current.org.update!(cap_site_key: "tenant-site-key", cap_secret_key: "tenant-secret-key")

    with_env(
      "CAP_DEVELOPMENT_SITE_KEY" => "development-site-key",
      "CAP_DEVELOPMENT_SECRET_KEY" => "development-secret-key") do
      with_rails_env("development") do
        assert_equal "development-site-key", Cap.site_key(Current.org)
        assert_equal "development-secret-key", Cap.secret_key(Current.org)
      end
    end
  end

  test "ignores development keys outside development" do
    Current.org.update!(cap_site_key: "tenant-site-key", cap_secret_key: "tenant-secret-key")

    with_env(
      "CAP_DEVELOPMENT_SITE_KEY" => "development-site-key",
      "CAP_DEVELOPMENT_SECRET_KEY" => "development-secret-key") do
      assert_equal "tenant-site-key", Cap.site_key(Current.org)
      assert_equal "tenant-secret-key", Cap.secret_key(Current.org)
    end
  end

  test "falls back to the public API URL for server-side requests" do
    with_env("CAP_API_URL" => "https://cap.test", "CAP_INTERNAL_API_URL" => nil) do
      assert_equal "https://cap.test", Cap.api_url
      assert_equal "https://cap.test", Cap.internal_api_url
    end
  end

  test "uses a separate internal API URL when configured" do
    with_env(
      "CAP_API_URL" => "https://cap.test",
      "CAP_INTERNAL_API_URL" => "http://cap.internal") do
      assert_equal "https://cap.test", Cap.api_url
      assert_equal "http://cap.internal", Cap.internal_api_url
    end
  end
end
