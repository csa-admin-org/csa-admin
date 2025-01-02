# frozen_string_literal: true

module MailTemplatesHelper
  def mail_templates(title)
    MailTemplate.create!(title: title)
  end
end
