# frozen_string_literal: true

require "test_helper"

class CapHelperTest < ActionView::TestCase
  test "raises in production when site key is missing" do
    Current.org.update!(cap_site_key: nil)

    with_rails_env("production") do
      error = assert_raises(RuntimeError) { cap_token_field }

      assert_equal "Missing Cap site key for acme", error.message
    end
  end

  test "renders development site key in development" do
    with_env("CAP_DEVELOPMENT_SITE_KEY" => "development-site-key") do
      with_rails_env("development") do
        html = cap_token_field

        assert_includes html, "data-cap-api-endpoint-value=\"https://cap.csa-admin.org/development-site-key/\""
        assert_includes html, "data-cap-verifying-message-value=\"Verifying…\""
        assert_includes html, "data-cap-failed-message-value=\"Security verification failed. Please reload the page.\""
        assert_includes html, "data-cap-target=\"tooltipTemplate\""
        assert_includes html, "data-tooltip-target=\"content\""
      end
    end
  end
end
