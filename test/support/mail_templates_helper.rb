# frozen_string_literal: true

module MailTemplatesHelper
  def mail_templates(title)
    MailTemplate.find_or_create_by!(title: title)
  end
end
