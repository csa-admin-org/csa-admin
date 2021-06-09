class ACPJob < ApplicationJob
  queue_as :low

  def perform(job_class)
    job = job_class.constantize
    ACP.perform_each do
      job.perform_later
    end
  end
end
