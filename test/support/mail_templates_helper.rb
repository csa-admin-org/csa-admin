module MailTemplatesHelper
  def mail_templates(titles)
    Array(titles).map do |title|
      MailTemplate.create!(title: title)
    end
  end

  def mail_template(title)
    MailTemplate.create!(title: title)
  end
end
