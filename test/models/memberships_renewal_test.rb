# frozen_string_literal: true

require "test_helper"

class MembershipsRenewalTest < ActiveSupport::TestCase
  setup { travel_to "2024-01-01" }

  test "open_all! skips memberships when no form-offered depot has deliveries in the renewal year" do
    mail_templates(:membership_renewal).update!(active: true)
    empty = assign_depot_without_renewal_year_deliveries!(memberships(:jane))
    hide_other_depots!(empty.depot)
    working = memberships(:bob)

    MembershipsRenewal.new(2024).open_all!
    perform_enqueued_jobs

    assert_nil empty.reload.renewal_opened_at
    assert working.reload.renewal_opened_at
  end

  test "open_all! opens a membership whose current depot is empty when another visible depot has deliveries" do
    mail_templates(:membership_renewal).update!(active: true)
    empty = assign_depot_without_renewal_year_deliveries!(memberships(:jane))
    working = memberships(:bob)

    MembershipsRenewal.new(2024).open_all!
    perform_enqueued_jobs

    assert empty.reload.renewal_opened_at
    assert working.reload.renewal_opened_at
  end

  test "renew_all! raises when a membership depot has no deliveries in the renewal year" do
    membership = assign_depot_without_renewal_year_deliveries!(memberships(:jane))

    error = nil
    assert_no_enqueued_jobs only: MembershipRenewalJob do
      error = assert_raises(MembershipRenewal::MissingDeliveriesError) do
        MembershipsRenewal.new(2024).renew_all!
      end
    end

    assert_equal missing_depot_deliveries_message(membership), error.message
  end
end
