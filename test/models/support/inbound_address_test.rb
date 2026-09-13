# frozen_string_literal: true

require "test_helper"

class Support::InboundAddressTest < ActiveSupport::TestCase
  test "parses ticket token and tenant" do
    address = Support::InboundAddress.parse("ticket-deadbeef-acme@support.csa-admin.org")

    assert address.recognized?
    assert_equal "deadbeef", address.token
    assert_equal "acme", address.tenant
    assert_not address.convert?
  end

  test "parses convert address" do
    address = Support::InboundAddress.parse("ticket-acme@support.csa-admin.org")

    assert address.recognized?
    assert address.convert?
    assert_equal "acme", address.tenant
    assert_nil address.token
  end

  test "unknown tenant is not recognized" do
    assert_nil Support::InboundAddress.parse("ticket-deadbeef-unknown@support.csa-admin.org")
    assert_nil Support::InboundAddress.parse("ticket-unknown@support.csa-admin.org")
  end

  test "other domains are ignored" do
    assert_nil Support::InboundAddress.parse("ticket-deadbeef-acme@csa-admin.org")
  end

  test "prefers token form over convert when both appear" do
    address = Support::InboundAddress.parse(
      "other@example.com",
      "ticket-acme@support.csa-admin.org",
      "ticket-aaaaaaaa-acme@support.csa-admin.org")

    assert_equal "aaaaaaaa", address.token
    assert_not address.convert?
  end

  test "demo tenant is flagged" do
    Tenant.stub(:exists?, ->(name) { name.to_s == "demo-en" }) do
      address = Support::InboundAddress.parse("ticket-demo-en@support.csa-admin.org")

      assert address.recognized?
      assert address.demo?
    end
  end

  test "normalizes message id" do
    assert_equal "<abc>", Support::InboundAddress.normalize_message_id("abc")
    assert_equal "<abc>", Support::InboundAddress.normalize_message_id("<abc>")
    assert_nil Support::InboundAddress.normalize_message_id(nil)
  end

  test "operator_email? matches ultra, support, and plus-high" do
    with_env(
      "ULTRA_ADMIN_EMAIL" => "info@csa-admin.org",
      "SUPPORT_EMAIL" => "support@csa-admin.org") do
      assert Support::InboundAddress.operator_email?("info@csa-admin.org")
      assert Support::InboundAddress.operator_email?("support@csa-admin.org")
      assert Support::InboundAddress.operator_email?("support+high@csa-admin.org")
      assert_not Support::InboundAddress.operator_email?("stranger@gmail.com")
    end
  end
end
