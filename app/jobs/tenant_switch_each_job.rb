# frozen_string_literal: true

class TenantSwitchEachJob < ActiveJob::Base
  queue_as :low

  def perform(job_class)
    job = job_class.constantize
    Tenant.switch_each { job.perform_later }
  end
end
