# frozen_string_literal: true

require "test_helper"

class Tenant::MiddlewareTest < ActiveSupport::TestCase
  test "returns not found for hosts without a registry domain" do
    response = middleware.call(Rack::MockRequest.env_for("http://localhost/config/master.key"))

    assert_equal 404, response.first
  end

  private

  def middleware
    Tenant::Middleware.new(->(_) { [ 200, {}, [ "OK" ] ] })
  end
end
