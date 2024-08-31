# frozen_string_literal: true

class ScheduledJob < ActiveJob::Base
  queue_as :low

  def perform(job_class)
    job = job_class.constantize
    Organization.switch_each { job.perform_later }
  end
end
