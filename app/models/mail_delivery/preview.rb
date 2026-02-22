# frozen_string_literal: true

module MailDelivery::Preview
  extend ActiveSupport::Concern

  def store_preview_from!(message)
    return if self.subject.present?

    update!(
      subject: message.subject,
      content: extract_html_content(message))
  end

  def mail_preview
    html = content.to_s

    if html.include?("<html") || html.include?("<!DOCTYPE")
      # New format: full HTML stored by ProcessJob
      html
        .gsub(%r{<img src="https?://example.org}, "<img src=\"#{Current.org.members_url}")
        .gsub(/<a\s/, '<a target="_blank" rel="noopener noreferrer" ')
    else
      # Legacy format: Liquid body, re-render through content_mail
      mailer = ApplicationMailer.new
      rendered = mailer.send(:content_mail,
        html
          .gsub(%r{<img src="https?://example.org}, "<img src=\"#{Current.org.members_url}")
          .gsub(/<a\s/, '<a target="_blank" rel="noopener noreferrer" '),
        subject: subject
      ).body.encoded
      rendered.gsub(/<!--\s*BEGIN.*?-->/m, "").gsub(/<!--\s*END.*?-->/m, "")
    end
  rescue => e
    e.message
  end

  private

  def extract_html_content(message)
    if message.multipart?
      message.html_part&.body&.decoded
    else
      message.body.decoded
    end
  end
end
