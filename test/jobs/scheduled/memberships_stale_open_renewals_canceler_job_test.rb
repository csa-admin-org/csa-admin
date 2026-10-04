# frozen_string_literal: true

require "test_helper"

class Scheduled::MembershipsStaleOpenRenewalsCancelerJobTest < ActiveJob::TestCase
  test "does not cancel opened renewals before the first current-year delivery" do
    travel_to "2025-04-06"
    open_renewal! memberships(:jane), at: 1.year.ago

    assert_not Delivery.current_year_ongoing?

    perform_job

    assert memberships(:jane).reload.renewal_opened?
  end

  test "cancels past-FY opened renewals after the first current-year delivery" do
    travel_to "2025-04-08"
    open_renewal! memberships(:jane), at: 1.year.ago
    open_renewal! memberships(:john_past), at: 2.years.ago
    open_renewal! memberships(:john_future), at: 1.day.ago
    memberships(:bob).update_columns(
      renew: true, renewed_at: nil, renewal_opened_at: nil)

    assert Delivery.current_year_ongoing?

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      perform_job
    end

    assert memberships(:jane).reload.canceled?
    assert_nil memberships(:jane).renewal_opened_at
    assert memberships(:john_past).reload.canceled?
    assert memberships(:john_future).reload.renewal_opened?
    assert memberships(:john).reload.renewed?
    assert memberships(:bob).reload.renewal_pending?
  end

  private

  def perform_job
    perform_enqueued_jobs do
      Scheduled::MembershipsStaleOpenRenewalsCancelerJob.perform_later
    end
  end

  def open_renewal!(membership, at:)
    membership.update_columns(
      renew: true,
      renewed_at: nil,
      renewal_opened_at: at)
  end
end
