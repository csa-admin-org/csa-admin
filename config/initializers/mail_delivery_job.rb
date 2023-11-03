Rails.application.config.after_initialize do
  ActionMailer::MailDeliveryJob.send(:include, CurrentContext)
end
