# frozen_string_literal: true

require "test_helper"

class TenantTest < ActiveSupport::TestCase
  test "find_by host" do
    assert_equal "acme", Tenant.find_by(host: "admin.acme.test")
    assert_equal "acme", Tenant.find_by(host: "foo.acme.test")
    assert_nil Tenant.find_by(host: "admin.unknown.test")
  end

  test "domain" do
    assert_equal "acme", Tenant.current
    assert_equal "acme.test", Tenant.domain
  end

  test "inside? / outside?" do
    assert_equal "acme", Tenant.current
    assert Tenant.inside?
    assert_not Tenant.outside?
  end

  test "exists?" do
    assert Tenant.exists?("acme")
    assert_not Tenant.exists?("unknown")
  end

  test "connect to unknown tenant" do
    assert_equal "acme", Tenant.current
    assert_raises RuntimeError, match: /Unknown tenant 'unknown'/ do
      Tenant.switch("unknown") { }
    end
  end
end
