# frozen_string_literal: true

require "test_helper"

class TenantTest < ActiveSupport::TestCase
  test "find_by host" do
    assert_equal "acme", Tenant.find_by(host: "admin.acme.test")
    assert_equal "acme", Tenant.find_by(host: "admin.acme.localhost")
    assert_equal "acme", Tenant.find_by(host: "foo.acme.test")
    assert_equal "beta", Tenant.find_by(host: "admin.beta.test")
    assert_nil Tenant.find_by(host: "admin.unknown.test")
    assert_nil Tenant.find_by(host: "localhost")
  end

  test "admin and members hosts" do
    assert_equal "acme", Tenant.current
    assert_equal "admin.acme.test", Tenant.admin_host
    assert_equal "members.acme.test", Tenant.members_host
  end

  test "inside? / outside?" do
    assert_equal "acme", Tenant.current
    assert Tenant.inside?
    assert_not Tenant.outside?
  end

  test "exists?" do
    assert Tenant.exists?("acme")
    assert Tenant.exists?("beta")
    assert_not Tenant.exists?("unknown")
  end

  test "find_with_aliases" do
    assert_equal "acme", Tenant.find_with_aliases("ac")
  end

  test "local_url_options keep hosts outside development" do
    assert_equal(
      { protocol: "https", host: "members.acme.test" },
      Tenant.local_url_options("members.acme.test"))
  end

  test "local_url_options use .test in development" do
    with_rails_env("development") do
      assert_equal(
        { protocol: "https", host: "membres.ragedevert.test" },
        Tenant.local_url_options("membres.ragedevert.ch"))
      assert_equal "https://membres.ragedevert.test",
        Tenant.local_url("membres.ragedevert.ch")
    end
  end

  test "local_url_options use localhost when DEV_ORIGIN is localhost" do
    with_rails_env("development") do
      with_env("DEV_ORIGIN" => "localhost", "PORT" => "3001") do
        assert_equal(
          { protocol: "http", host: "membres.ragedevert.localhost", port: "3001" },
          Tenant.local_url_options("membres.ragedevert.ch"))
        assert_equal "http://membres.ragedevert.localhost:3001",
          Tenant.local_url("membres.ragedevert.ch")
      end
    end
  end

  test "connect to unknown tenant" do
    assert_equal "acme", Tenant.current
    assert_raises RuntimeError, match: /Unknown tenant 'unknown'/ do
      Tenant.switch("unknown") { }
    end
  end
end
