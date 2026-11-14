# frozen_string_literal: true

require "test_helper"

class Tenant::MiddlewareTest < ActiveSupport::TestCase
  test "returns not found for hosts without a registry domain" do
    response = middleware.call(Rack::MockRequest.env_for("http://localhost/config/master.key"))

    assert_equal 404, response.first
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

  test "does not switch tenant on mc subdomain" do
    Tenant.disconnect
    switched = false
    app = Tenant::Middleware.new(->(_) {
      switched = Tenant.inside?
      [ 200, {}, [ "OK" ] ]
    })

    response = app.call(Rack::MockRequest.env_for("http://mc.csa-admin.test/"))

    assert_equal 200, response.first
    assert_not switched
  end

  test "passes through development launcher hosts without a tenant" do
    Tenant.disconnect
    switched = false
    app = Tenant::Middleware.new(->(_) {
      switched = Tenant.inside?
      [ 200, {}, [ "OK" ] ]
    })

    Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
      Tenant::Middleware::DEV_LAUNCHER_HOSTS.each do |host|
        response = app.call(Rack::MockRequest.env_for("http://#{host}/"))

        assert_equal 200, response.first, host
        assert_not switched, host
      end
    end
  end

  private

  def middleware
    Tenant::Middleware.new(->(_) { [ 200, {}, [ "OK" ] ] })
  end
end
