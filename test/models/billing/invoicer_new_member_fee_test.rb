# frozen_string_literal: true

require "test_helper"

class Billing::InvoicerNewMemberFeeTest < ActiveSupport::TestCase
  def invoice(member, **attrs)
    Billing::InvoicerNewMemberFee.invoice(member, **attrs)
  end

  test "create invoice for recent new member" do
    travel_to "2023-05-01"
    member = members(:john)

    assert_difference -> { member.invoices.count }, 1 do
      invoice(member)
    end

    invoice = member.invoices.last
    assert_equal Date.current, invoice.date
    assert_equal "NewMemberFee", invoice.entity_type
    assert_equal 33, invoice.amount
    assert_equal 1, invoice.items.count
    assert_equal "Empty baskets", invoice.items.first.description
    assert_equal 33, invoice.items.first.amount
  end

  test "do nothing if new_member_fee is not enabled" do
    travel_to "2023-05-01"
    org(features: [])
    member = members(:john)

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member is not active" do
    member = members(:aria)

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member already has a new_member_fee invoice" do
    travel_to "2023-05-01"
    member = members(:john)

    assert_difference -> { member.invoices.count }, 1 do
      invoice(member)
    end
    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member is still on trial basket" do
    member = members(:jane)

    assert_equal "2024-04-11", member.baskets.trial.last.delivery.date.to_s

    travel_to "2024-04-11"
    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member first non-trial basket is no more recent" do
    member = members(:jane)

    assert_equal "2024-04-11", member.baskets.trial.last.delivery.date.to_s

    travel_to member.baskets.trial.last.delivery.date + 3.weeks + 1.day
    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member is still on trial spanning two fiscal years" do
    travel_to "2024-05-20"
    org(trial_baskets_count: 4)

    member = members(:mary)
    member.update_columns(trial_baskets_count: 4)

    # Membership 1: 3 baskets (May 20, May 27, Jun 3) — all trial
    m1 = create_membership(
      member: member,
      started_on: "2024-05-20",
      ended_on: "2024-12-31"
    )
    # Membership 2: 10 baskets (Apr 7 – Jun 9) — first one is trial
    m2 = create_membership(
      member: member,
      started_on: "2025-01-01",
      ended_on: "2025-12-31"
    )
    member.reload

    assert_equal 3, m1.trial_baskets_count
    assert_equal 1, m2.trial_baskets_count

    # m1's trial baskets are all past, but m2 still has a remaining trial basket
    travel_to "2024-06-04"
    m1.update_baskets_counts!
    m2.update_baskets_counts!
    member.reload

    assert_equal 0, m1.remaining_trial_baskets_count
    assert_equal 1, m2.remaining_trial_baskets_count

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "create invoice after cross-year trial ends" do
    travel_to "2024-05-20"
    org(trial_baskets_count: 4)

    member = members(:mary)
    member.update_columns(trial_baskets_count: 4)

    m1 = create_membership(
      member: member,
      started_on: "2024-05-20",
      ended_on: "2024-12-31"
    )
    m2 = create_membership(
      member: member,
      started_on: "2025-01-01",
      ended_on: "2025-12-31"
    )
    member.reload

    # Last trial basket is Apr 7, 2025 (first delivery in m2)
    assert_equal "2025-04-07", member.baskets.trial.last.delivery.date.to_s

    # Trial fully over, within 3-week window
    travel_to "2025-04-08"
    m1.update_baskets_counts!
    m2.update_baskets_counts!
    member.reload

    assert_equal 0, m2.remaining_trial_baskets_count

    assert_difference -> { member.invoices.count }, 1 do
      invoice(member)
    end
  end

  test "do nothing if cross-year trial ended more than 3 weeks ago" do
    travel_to "2024-05-20"
    org(trial_baskets_count: 4)

    member = members(:mary)
    member.update_columns(trial_baskets_count: 4)

    m1 = create_membership(
      member: member,
      started_on: "2024-05-20",
      ended_on: "2024-12-31"
    )
    m2 = create_membership(
      member: member,
      started_on: "2025-01-01",
      ended_on: "2025-12-31"
    )
    member.reload

    # 3 weeks + 1 day after last trial basket (Apr 7, 2025)
    travel_to "2025-04-29"
    m1.update_baskets_counts!
    m2.update_baskets_counts!
    member.reload

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end
end
