# frozen_string_literal: true

require "test_helper"

class TenantSwitchEachJobTest < ActiveJob::TestCase
  test "enqueues the named job once per tenant without nesting a switch" do
    assert_equal ActiveJob::Base, TenantSwitchEachJob.superclass

    Tenant.disconnect
    TenantSwitchEachJob.perform_now("Scheduled::PromotionsArchiverJob")

    tenants = enqueued_jobs
      .select { |job| job["job_class"] == "Scheduled::PromotionsArchiverJob" }
      .map { |job| job["arguments"].last["tenant"] }

    assert_equal %w[acme beta], tenants
  ensure
    Tenant.connect("acme")
  end
end
