# frozen_string_literal: true

require "test_helper"

class Invoice::EntityTypeTest < ActiveSupport::TestCase
  test "sets entity_type to ActivityParticipation with missing_activity_participations_count" do
    invoice = Invoice.new(
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: 2025,
      activity_price: 21)
    invoice.validate

    assert_equal "ActivityParticipation", invoice.entity_type
  end

  test "item amounts are summed as entered" do
    invoice = Invoice.new(
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10.11" },
        "1" => { description: "Cool free thing", amount: "0" },
        "2" => { description: "Cool expensive thing", amount: "32.33" }
      })

    assert_equal "Other", invoice.entity_type
    assert_equal 10.11, invoice.items.first.amount
    assert_equal 32.33, invoice.items.last.amount
    assert_equal 42.44, invoice.amount
  end

  test "when annual fee only" do
    invoice = create_annual_fee_invoice

    assert invoice.annual_fee.present?
    assert_equal "AnnualFee", invoice.entity_type
    assert_nil invoice.memberships_amount
    assert_equal invoice.annual_fee, invoice.amount
  end

  test "membership_type?" do
    invoice = create_membership_invoice
    assert invoice.membership_type?
    assert_not invoice.activity_participation_type?
    assert_not invoice.share_type?
    assert_not invoice.shop_order_type?
    assert_not invoice.other_type?
  end

  test "activity_participation_type?" do
    invoice = Invoice.new(
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: 2025,
      activity_price: 21)
    invoice.validate

    assert invoice.activity_participation_type?
    assert_not invoice.membership_type?
  end

  test "share_type?" do
    org(share_price: 250, shares_number: 1)
    invoice = Invoice.new(shares_number: 1)

    assert invoice.share_type?
    assert_not invoice.membership_type?
  end

  test "other_type?" do
    invoice = Invoice.new(
      items_attributes: {
        "0" => { description: "Something", amount: "10" }
      })

    assert invoice.other_type?
    assert_not invoice.membership_type?
  end

  test "entity_types returns all possible types" do
    types = Invoice.entity_types

    assert_includes types, "Membership"
    assert_includes types, "Other"
    assert_includes types, "ActivityParticipation"
    assert_includes types, "Shop::Order"
    assert_includes types, "AnnualFee"
    assert_includes types, "Share"
    assert_includes types, "NewMemberFee"
  end
end
