# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActionMailer::MailDeliveryJob.include TenantContext
  ActionMailer::MailDeliveryJob.retry_on Postmark::TimeoutError
  ActionMailer::MailDeliveryJob.discard_on ActiveJob::DeserializationError::RecordNotFound

  Support::MailDeliveryJob.retry_on ActiveStorage::FileNotFoundError,
    wait: 2.seconds,
    attempts: Support::MailDeliveryJob::MISSING_FILE_ATTEMPTS

  ActionMailer::Base.register_interceptor(DemoMailInterceptor)
end
