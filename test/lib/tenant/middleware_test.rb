# frozen_string_literal: true

require "test_helper"

class Tenant::MiddlewareTest < ActiveSupport::TestCase
  test "returns not found for hosts without a registry domain" do
    response = middleware.call(Rack::MockRequest.env_for("http://localhost/config/master.key"))

    assert_equal 404, response.first
  end

  test "redirects a development loopback browser to DEV_BROWSER_HOST" do
    with_rails_env("development") do
      with_env("DEV_ORIGIN" => "localhost", "DEV_BROWSER_HOST" => "admin.acp-admin.ch", "PORT" => "3000") do
        status, headers, = middleware.call(
          Rack::MockRequest.env_for("http://127.0.0.1:57741/login?next=1"))

        assert_equal 302, status
        assert_equal "http://admin.acp-admin.localhost:57741/login?next=1", headers["location"]
      end
    end
  end

  test "keeps a loopback 404 when no development browser host is configured" do
    with_rails_env("development") do
      with_env("DEV_BROWSER_HOST" => nil) do
        status, = middleware.call(Rack::MockRequest.env_for("http://127.0.0.1:57741/"))

        assert_equal 404, status
      end
    end
  end

  test "does not switch tenant on query subdomain" do
    Tenant.disconnect
    switched = false
    app = Tenant::Middleware.new(->(_) {
      switched = Tenant.inside?
      [ 200, {}, [ "OK" ] ]
    })

    response = app.call(Rack::MockRequest.env_for("http://query.acme.test/"))

    assert_equal 200, response.first
    assert_not switched
  end

  private

  def middleware
    Tenant::Middleware.new(->(_) { [ 200, {}, [ "OK" ] ] })
  end
end
