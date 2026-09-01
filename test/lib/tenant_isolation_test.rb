# frozen_string_literal: true

require "test_helper"

class TenantIsolationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "switch to a different tenant raises while already inside one" do
    assert_equal "acme", Tenant.current
    error = assert_raises(RuntimeError) { Tenant.switch("beta") { } }
    assert_match "Illegal tenant switch (acme => beta)", error.message
  end

  test "switch_each visits every tenant" do
    seen = []
    Tenant.switch_each { |tenant| seen << [ tenant, Tenant.current ] }
    assert_equal [ %w[acme acme], %w[beta beta] ], seen
    assert Tenant.outside?
  end

  test "switch_each visits an explicit tenant list" do
    seen = []
    Tenant.switch_each(%w[acme beta]) { |tenant| seen << tenant }
    assert_equal %w[acme beta], seen
    assert Tenant.outside?
  end

  test "a write on acme is invisible on beta" do
    marker = "isolation-#{SecureRandom.hex(8)}"
    member = members(:john)
    original_emails = member.emails

    member.update_columns(emails: marker)
    assert Member.unscoped.exists?(emails: marker)

    with_connected_tenant("beta") do
      assert_equal "beta", Tenant.current
      assert_not Member.unscoped.exists?(emails: marker)
    end
  ensure
    member&.update_columns(emails: original_emails) if original_emails
  end

  test "an acme session row is missing on beta" do
    session = sessions(:ultra)

    with_connected_tenant("beta") do
      assert_not Session.unscoped.exists?(id: session.id)
    end
  end
end
