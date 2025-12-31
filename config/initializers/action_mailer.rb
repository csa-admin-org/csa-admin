# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActionMailer::MailDeliveryJob.include TenantContext
  ActionMailer::MailDeliveryJob.retry_on Postmark::TimeoutError
  ActionMailer::MailDeliveryJob.discard_on ActiveJob::DeserializationError

  ActionMailer::Base.register_interceptor(DemoMailInterceptor)
end
