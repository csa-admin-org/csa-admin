Rails.application.configure do
  if Rails.env.test?
    config.active_job.queue_adapter = :inline
  else
    config.active_job.queue_adapter = :sucker_punch
  end
end
