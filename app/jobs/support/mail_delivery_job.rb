# frozen_string_literal: true

class Support::MailDeliveryJob < ActionMailer::MailDeliveryJob
  # Includes the first run. The mailer skips a file that is still missing
  # on the last attempt so the alert is sent anyway.
  # retry_on is registered in config/initializers/action_mailer.rb, after
  # MailDeliveryJob's own handlers, so this job keeps the Postmark retry
  # and the deserialization discard.
  MISSING_FILE_ATTEMPTS = 3

  def perform(mailer, mail_method, delivery_method, args:, kwargs: nil, params: nil)
    params = (params || {}).merge(missing_attachment_attempt: executions)
    super(
      mailer,
      mail_method,
      delivery_method,
      args: args,
      kwargs: kwargs,
      params: params)
  end
end
