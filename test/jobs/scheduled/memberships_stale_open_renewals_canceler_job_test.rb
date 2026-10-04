# frozen_string_literal: true

require "test_helper"

class Scheduled::MembershipsStaleOpenRenewalsCancelerJobTest < ActiveJob::TestCase
  test "does not cancel open renewals before the current year is delivering" do
    last_year = mark_open_renewal!(memberships(:jane))
    leftover = mark_open_renewal!(memberships(:john_past))
    current_year = mark_open_renewal!(memberships(:john_future))

    travel_to "2025-01-05"
    Current.reset

    perform_enqueued_jobs do
      Scheduled::MembershipsStaleOpenRenewalsCancelerJob.perform_later
    end

    assert last_year.reload.renewal_opened?
    assert leftover.reload.renewal_opened?
    assert current_year.reload.renewal_opened?
  end

  test "cancels past-FY open renewals after the current year has started delivering" do
    last_year = mark_open_renewal!(memberships(:jane))
    leftover = mark_open_renewal!(memberships(:john_past))
    current_year = mark_open_renewal!(memberships(:john_future))
    pending = memberships(:bob)
    renewed = memberships(:john)

    travel_to "2025-04-11"
    Current.reset

    assert_no_difference -> { MembershipMailer.deliveries.size } do
      assert_no_difference -> { AdminMailer.deliveries.size } do
        perform_enqueued_jobs do
          Scheduled::MembershipsStaleOpenRenewalsCancelerJob.perform_later
        end
      end
    end

    assert last_year.reload.canceled?
    assert leftover.reload.canceled?
    assert current_year.reload.renewal_opened?
    assert pending.reload.renewal_pending?
    assert renewed.reload.renewed?
  end

  private

  def mark_open_renewal!(membership)
    membership.update_columns(
      renew: true,
      renewed_at: nil,
      renewal_opened_at: Time.current)
    membership.reload
  end
end
