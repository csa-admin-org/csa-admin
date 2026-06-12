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
end
