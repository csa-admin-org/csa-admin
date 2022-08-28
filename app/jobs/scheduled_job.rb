class ScheduledJob < ActiveJob::Base
  queue_as :low

  def perform(job_class)
    job = job_class.constantize
    ACP.switch_each { job.perform_later }
  end
end
