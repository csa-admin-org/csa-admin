# frozen_string_literal: true

require "test_helper"

class MembershipsRenewalTest < ActiveSupport::TestCase
  setup { travel_to "2024-01-01" }

  test "open_all! skips memberships whose depot has no deliveries in the renewal year" do
    mail_templates(:membership_renewal).update!(active: true)
    empty = assign_depot_without_renewal_year_deliveries!(memberships(:jane))
    working = memberships(:bob)

    MembershipsRenewal.new(2024).open_all!
    perform_enqueued_jobs

    assert_nil empty.reload.renewal_opened_at
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
