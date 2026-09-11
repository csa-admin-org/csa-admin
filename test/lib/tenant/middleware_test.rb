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

  private

  def middleware
    Tenant::Middleware.new(->(_) { [ 200, {}, [ "OK" ] ] })
  end
end
