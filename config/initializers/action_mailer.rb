# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActionMailer::MailDeliveryJob.retry_on Postmark::TimeoutError
end
