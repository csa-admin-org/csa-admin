# frozen_string_literal: true

require "test_helper"

class FaviconsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  test "redirects attached logo favicon variant to storage service" do
    attach_logo
    Current.org.logo.variant(resize_to_fill: [ 32, 32 ]).processed

    downloads = []
    subscriber = ActiveSupport::Notifications.subscribe("service_download.active_storage") do
      downloads << true
    end

    with_tenant_admin_host("admin.acme.ch") do
      begin
        get "/favicon"
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end

    assert_redirected_to %r{\Ahttp://admin\.acme\.test/rails/active_storage/disk/}
    assert_empty downloads
    assert_match "public", response.headers["Cache-Control"]
    assert_match "max-age=#{ActiveStorage.service_urls_expire_in.to_i}", response.headers["Cache-Control"]
  end

  test "serves resized bundled logo when tenant has no logo" do
    Current.org.logo.purge

    get "/favicon"

    image = Vips::Image.new_from_buffer(response.body, "")
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal 32, image.width
    assert_equal 32, image.height
  end

  private

  def attach_logo
    Current.org.logo.attach(
      io: file_fixture("logo-valid.png").open,
      filename: "logo.png",
      content_type: "image/png")
    Current.org.save!
  end

  def with_tenant_admin_host(host)
    Tenant.singleton_class.alias_method :original_admin_host, :admin_host
    Tenant.define_singleton_method(:admin_host) { host }
    yield
  ensure
    Tenant.singleton_class.alias_method :admin_host, :original_admin_host
    Tenant.singleton_class.remove_method :original_admin_host
  end
end
