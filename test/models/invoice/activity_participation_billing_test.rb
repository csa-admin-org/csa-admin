# frozen_string_literal: true

require "test_helper"

class Invoice::ActivityParticipationBillingTest < ActiveSupport::TestCase
  test "updates membership activity_participations_accepted" do
    membership = memberships(:john)
    invoice = Invoice.new(
      date: Date.current,
      member: members(:john),
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: membership.fiscal_year,
      activity_price: 60)

    assert_changes -> { membership.reload.activity_participations_accepted }, from: 2, to: 4 do
      invoice.save!
      perform_enqueued_jobs
    end

    assert_changes -> { membership.reload.activity_participations_accepted }, from: 4, to: 2 do
      invoice.reload.destroy_or_cancel!
      perform_enqueued_jobs
    end
  end

  test "validates activity_price presence when missing_activity_participations_count is set" do
    invoice = Invoice.new(
      missing_activity_participations_count: 1,
      missing_activity_participations_fiscal_year: 2025,
      activity_price: nil)

    assert_not invoice.valid?
    assert_includes invoice.errors[:activity_price], "is not a number"
  end

  test "sets entity_type to ActivityParticipation with missing_activity_participations_count" do
    invoice = Invoice.new(
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: 2025,
      activity_price: 21)
    invoice.validate

    assert_equal "ActivityParticipation", invoice.entity_type
    assert_equal 2, invoice.missing_activity_participations_count
    assert_equal 2025, invoice.missing_activity_participations_fiscal_year.year
    assert_equal 42, invoice.amount
  end

  test "automatically sets fiscal year and participation count" do
    part = activity_participations(:john_harvest)
    invoice = Invoice.new(entity: part)
    invoice.validate

    assert_equal part.member, invoice.member
    assert_equal 2, invoice.missing_activity_participations_count
    assert_equal FiscalYear.for(2024), invoice.missing_activity_participations_fiscal_year
  end
end
