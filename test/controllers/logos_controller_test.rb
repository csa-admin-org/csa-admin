# frozen_string_literal: true

require "test_helper"

class LogosControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  test "redirects attached logo to storage service" do
    attach_logo

    downloads = []
    subscriber = ActiveSupport::Notifications.subscribe("service_download.active_storage") do
      downloads << true
    end

    begin
      get logo_path("acme")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    assert_redirected_to %r{\Ahttp://admin\.acme\.test/rails/active_storage/disk/}
    assert_empty downloads
    assert_match "public", response.headers["Cache-Control"]
    assert_match "max-age=#{ActiveStorage.service_urls_expire_in.to_i}", response.headers["Cache-Control"]
  end

  test "serves bundled logo when tenant has no logo" do
    Current.org.logo.purge

    get logo_path("acme")

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal Rails.root.join("app/assets/images/logo.png").binread, response.body
  end

  test "returns not found for unknown tenant" do
    get logo_path("unknown")

    assert_response :not_found
  end

  private

  def attach_logo
    Current.org.logo.attach(
      io: file_fixture("logo-valid.png").open,
      filename: "logo.png",
      content_type: "image/png")
    Current.org.save!
  end
end
