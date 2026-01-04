# frozen_string_literal: true

require "test_helper"

class Notification::AdminMembershipsRenewalPendingTest < ActiveSupport::TestCase
  test "notify sends email 10 days before end of fiscal year" do
    travel_to "2024-01-01"
    admins(:ultra).update(notifications: [ "memberships_renewal_pending" ])
    end_of_fiscal_year = Current.fiscal_year.end_of_year
    memberships(:john).update!(renew: true, renewal_opened_at: nil, renewed_at: nil)

    travel_to end_of_fiscal_year - 11.days
    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notification::AdminMembershipsRenewalPending.notify
      perform_enqueued_jobs
    end

    travel_to end_of_fiscal_year - 10.days
    assert_difference -> { AdminMailer.deliveries.size }, 1 do
      Notification::AdminMembershipsRenewalPending.notify
      perform_enqueued_jobs
    end

    travel_to end_of_fiscal_year - 7.days
    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notification::AdminMembershipsRenewalPending.notify
      perform_enqueued_jobs
    end
  end
end
