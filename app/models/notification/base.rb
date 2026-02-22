# frozen_string_literal: true

class Notification::Base
  class << self
    def notify
      new.notify
    end

    def notify_later
      NotificationJob.perform_later(name)
    end

    def mail_template(title)
      @mail_template_title = title
    end

    def mail_template_title
      @mail_template_title
    end
  end

  def notify
    raise NotImplementedError, "#{self.class}#notify must be implemented"
  end

  private

  def mail_template_title
    self.class.mail_template_title
  end

  def mail_template_active?
    return false unless mail_template_title

    MailTemplate.active_template?(mail_template_title)
  end

  def mail_template
    return unless mail_template_title

    @mail_template ||= MailTemplate.active_template(mail_template_title)
  end

  def deliver(**args)
    MailTemplate.deliver(mail_template_title, **args)
  end
end
