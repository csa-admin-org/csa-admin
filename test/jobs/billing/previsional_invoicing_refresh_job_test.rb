# frozen_string_literal: true

require "test_helper"

class Billing::PrevisionalInvoicingRefreshJobTest < ActiveJob::TestCase
  test "refreshes previsional invoicing amounts for current and future memberships" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    # Clear the cached amounts to simulate stale data
    membership.update_column(:previsional_invoicing_amounts, {})
    assert_empty membership.reload.previsional_invoicing_amounts

    perform_enqueued_jobs do
      Billing::PrevisionalInvoicingRefreshJob.perform_later
    end

    membership.reload
    assert_equal({ "2024-01" => 200.0 }, membership.previsional_invoicing_amounts)
  end

  test "does not update past memberships" do
    travel_to "2025-06-01"
    past_membership = memberships(:john_past)
    past_membership.update_column(:previsional_invoicing_amounts, {})

    perform_enqueued_jobs do
      Billing::PrevisionalInvoicingRefreshJob.perform_later
    end

    assert_empty past_membership.reload.previsional_invoicing_amounts
  end

  test "enqueued when billing_starts_after_first_delivery changes" do
    assert_enqueued_with(job: Billing::PrevisionalInvoicingRefreshJob) do
      Current.org.update!(billing_starts_after_first_delivery: !Current.org.billing_starts_after_first_delivery?)
    end
  end

  test "enqueued when billing_ends_on_last_delivery_fy_month changes" do
    assert_enqueued_with(job: Billing::PrevisionalInvoicingRefreshJob) do
      Current.org.update!(billing_ends_on_last_delivery_fy_month: !Current.org.billing_ends_on_last_delivery_fy_month?)
    end
  end

  test "enqueued when recurring_billing_wday changes" do
    new_wday = (Current.org.recurring_billing_wday + 1) % 7
    assert_enqueued_with(job: Billing::PrevisionalInvoicingRefreshJob) do
      Current.org.update!(recurring_billing_wday: new_wday)
    end
  end

  test "not enqueued when unrelated billing settings change" do
    assert_no_enqueued_jobs(only: Billing::PrevisionalInvoicingRefreshJob) do
      Current.org.update!(send_closed_invoice: !Current.org.send_closed_invoice?)
    end
  end
end
