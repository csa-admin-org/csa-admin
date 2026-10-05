# frozen_string_literal: true

require "test_helper"

class Membership::RenewalTest < ActiveSupport::TestCase
  test "sets renew to true on create and false on update" do
    travel_to "2024-01-01"
    membership = create_membership(ended_on: "2024-12-31")
    assert membership.renew

    membership.reload
    membership.update!(ended_on: "2024-12-30")
    assert_not membership.renew
  end

  test "sets renew to false on create and true on update" do
    travel_to "2024-01-01"
    membership = create_membership(ended_on: "2024-12-30")
    assert_not membership.renew

    membership.reload
    membership.update!(ended_on: "2024-12-31")
    assert membership.renew
  end

  test "sets renew to false when changed manually" do
    travel_to "2024-01-01"
    membership = create_membership(ended_on: "2024-12-31")
    assert membership.renew

    membership.reload
    membership.update!(renew: false)
    assert_not membership.renew
  end

  test "prevents date modification when renewed" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.renewed_at = Time.current
    membership.ended_on = "2024-12-15"

    assert_not membership.valid?
    assert_includes membership.errors[:ended_on], "Membership already renewed"
  end

  test "mark_renewal_as_pending! sets renew to true when previously canceled" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.cancel!(renewal_annual_fee: true)

    assert_changes -> { membership.reload.renew }, from: false, to: true do
      membership.mark_renewal_as_pending!
    end

    assert membership.renewal_pending?
    assert_nil membership.reload.renewal_annual_fee
  end

  test "open_renewal! requires future deliveries to be present" do
    travel_to "2025-01-01"
    mail_templates(:membership_renewal).update!(active: true)
    membership = memberships(:john_future)

    assert_raises(MembershipRenewal::MissingDeliveriesError) do
      membership.open_renewal!
    end
  end

  test "open_renewal! sets renewal_opened_at and sends member-renewal email template" do
    travel_to "2024-01-01"
    mail_templates(:membership_renewal).update!(active: true)
    membership = memberships(:jane)

    assert_difference -> { MembershipMailer.deliveries.size }, 1 do
      assert_changes -> { membership.reload.renewal_opened_at }, from: nil do
        membership.open_renewal!
        perform_enqueued_jobs
      end
    end

    assert membership.renewal_opened?
    mail = MembershipMailer.deliveries.last
    assert_equal "Renew your membership", mail.subject
  end

  test "renew sets renewal_note attrs" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_difference -> { Membership.count } do
      membership.renew!(renewal_note: "I am very happy")
    end

    membership.reload
    assert membership.renewed?
    assert_equal "I am very happy", membership.renewal_note
  end

  test "cancel sets the membership renew to false" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update_column(:renewal_opened_at, Time.current)

    assert_no_difference -> { Membership.count } do
      membership.cancel!
    end

    membership.reload
    assert membership.canceled?
    assert_not membership.renew
    assert_nil membership.renewal_opened_at
    assert_nil membership.renewed_at
  end

  test "cancel cancels the membership with a renewal_note" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_no_difference -> { Membership.count } do
      membership.cancel!(renewal_note: "I am not happy")
    end

    membership.reload
    assert membership.canceled?
    assert_equal "I am not happy", membership.renewal_note
  end

  test "cancel cancels the membership with a renewal_annual_fee" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_no_difference -> { Membership.count } do
      membership.cancel!(renewal_annual_fee: "1")
    end

    membership.reload
    assert membership.canceled?
    assert_equal 30, membership.renewal_annual_fee
  end

  test "creating a new membership marks previous year's membership as renewed" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(renew: true, renewal_opened_at: 1.year.ago)

    travel_to "2025-01-01"
    assert_changes -> { membership.reload.renewal_state }, from: :renewal_opened, to: :renewed do
      create_membership(member: members(:jane))
    end
  end

  test "destroying renewed membership clears previous membership's renewed_at" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    assert_changes -> { membership.reload.renewed_at }, to: nil do
      renewed_membership.destroy!
    end
  end

  test "destroying renewed membership in new fiscal year cancels previous membership" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    assert_changes -> { membership.reload.renewed_at }, to: nil do
      assert_changes -> { membership.reload.renew }, to: false do
        travel_to renewed_membership.started_on do
          renewed_membership.destroy!
        end
      end
    end
  end

  test "destroying renewed membership mid-year still clears previous membership's renewed_at" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    # Simulate deleting the renewed membership mid-year (the bug scenario)
    travel_to "2025-06-15" do
      assert_changes -> { membership.reload.renewed_at }, to: nil do
        assert_changes -> { membership.reload.renew }, to: false do
          renewed_membership.destroy!
        end
      end
    end
  end

  test "destroying future membership keeps previous membership's renew flag true" do
    travel_to "2024-06-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    # Deleting a future year membership should keep renew: true
    assert_changes -> { membership.reload.renewed_at }, to: nil do
      assert_no_changes -> { membership.reload.renew } do
        renewed_membership.destroy!
      end
    end
    assert membership.reload.renew
  end

  test "destroying membership does nothing when previous membership was not renewed" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update_columns(renewed_at: nil)
    renewed_membership = memberships(:john_future)

    assert_no_changes -> { membership.reload.renew } do
      renewed_membership.destroy!
    end
  end

  test "updating billing_year_division syncs to renewed membership" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    assert_changes -> { renewed_membership.reload.billing_year_division }, from: 1, to: 4 do
      membership.update!(billing_year_division: 4)
    end
  end

  test "stale_open_renewals selects past-FY opened renewals including older leftovers" do
    travel_to "2025-04-11"
    Current.reset
    last_year = mark_open_renewal!(memberships(:jane))
    leftover = mark_open_renewal!(memberships(:john_past))
    current_year = mark_open_renewal!(memberships(:john_future))
    pending = memberships(:bob)
    renewed = memberships(:john)

    stale = Membership.stale_open_renewals

    assert_includes stale, last_year
    assert_includes stale, leftover
    assert_not_includes stale, current_year
    assert_not_includes stale, pending
    assert_not_includes stale, renewed
  end

  test "cancel_stale_open_renewals leaves late renewals open before the current year is delivering" do
    last_year = mark_open_renewal!(memberships(:jane))
    leftover = mark_open_renewal!(memberships(:john_past))
    current_year = mark_open_renewal!(memberships(:john_future))
    pending = memberships(:bob)
    renewed = memberships(:john)

    travel_to "2025-01-05"
    Current.reset
    assert_not Delivery.current_year_ongoing?

    Membership.cancel_stale_open_renewals

    assert last_year.reload.renewal_opened?
    assert leftover.reload.renewal_opened?
    assert current_year.reload.renewal_opened?
    assert pending.reload.renewal_pending?
    assert renewed.reload.renewed?
  end

  test "cancel_stale_open_renewals cancels past-FY opened leftovers once the current year is delivering" do
    last_year = mark_open_renewal!(memberships(:jane))
    leftover = mark_open_renewal!(memberships(:john_past))
    current_year = mark_open_renewal!(memberships(:john_future))
    pending = memberships(:bob)
    renewed = memberships(:john)

    travel_to "2025-04-11"
    Current.reset
    assert Delivery.current_year_ongoing?

    assert_no_difference -> { MembershipMailer.deliveries.size } do
      assert_no_difference -> { AdminMailer.deliveries.size } do
        Membership.cancel_stale_open_renewals
        perform_enqueued_jobs
      end
    end

    last_year.reload
    leftover.reload
    assert last_year.canceled?
    assert leftover.canceled?
    assert_not last_year.renew
    assert_not leftover.renew
    assert_nil last_year.renewal_opened_at
    assert_nil leftover.renewal_opened_at
    assert current_year.reload.renewal_opened?
    assert pending.reload.renewal_pending?
    assert renewed.reload.renewed?
  end

  test "cancel_stale_open_renewals cancels a past membership whose dates span two fiscal years and still processes the others" do
    invalid = mark_cross_fiscal_year_open_renewal!(memberships(:john_past))
    leftover = mark_open_renewal!(memberships(:jane))

    assert_not invalid.valid?
    assert_includes invalid.errors[:started_on], "must be in the same fiscal year"
    assert_includes invalid.errors[:ended_on], "must be in the same fiscal year"
    assert_raises(ActiveRecord::RecordInvalid) { invalid.cancel! }

    travel_to "2025-04-11"
    Current.reset
    assert Delivery.current_year_ongoing?

    Membership.cancel_stale_open_renewals

    invalid.reload
    leftover.reload
    assert invalid.canceled?
    assert leftover.canceled?
    assert_not invalid.renew
    assert_nil invalid.renewal_opened_at
  end

  test "cancel! itself sends no member or admin emails" do
    mail_templates(:membership_renewal).update!(active: true)
    mail_templates(:membership_renewal_reminder).update!(active: true)
    membership = memberships(:jane)
    mark_open_renewal!(membership)

    assert_no_difference -> { MembershipMailer.deliveries.size } do
      assert_no_difference -> { AdminMailer.deliveries.size } do
        membership.cancel!
        perform_enqueued_jobs
      end
    end

    assert membership.reload.canceled?
  end

  private

  def mark_open_renewal!(membership)
    membership.update_columns(
      renew: true,
      renewed_at: nil,
      renewal_opened_at: Time.current)
    membership.reload
  end

  def mark_cross_fiscal_year_open_renewal!(membership)
    membership.update_columns(
      started_on: Date.new(2023, 1, 1),
      ended_on: Date.new(2024, 6, 30),
      renew: true,
      renewed_at: nil,
      renewal_opened_at: Time.current)
    membership.reload
  end
end
