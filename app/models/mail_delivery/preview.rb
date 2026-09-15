# frozen_string_literal: true

module MailDelivery::Preview
  extend ActiveSupport::Concern

  def store_preview_from!(message)
    return if self.subject.present?

    update!(
      subject: message.subject,
      content: redact_sensitive_urls(extract_html_content(message)))
  end

  def mail_preview
    return unless content.present?

    html = redact_sensitive_urls(content)

    if html.include?("<html") || html.include?("<!DOCTYPE")
      # New format: full HTML stored by ProcessJob
      prepare_preview_html(html)
    else
      # Legacy format: Liquid body, re-render through content_mail
      mailer = ApplicationMailer.new
      rendered = mailer.send(:content_mail,
        prepare_preview_html(html),
        subject: subject
      ).body.encoded
      rendered.gsub(/<!--\s*BEGIN.*?-->/m, "").gsub(/<!--\s*END.*?-->/m, "")
    end
  rescue => e
    e.message
  end

  private

  SENSITIVE_HREF = %r{(href=["'])https?://[^"']+/(?:sessions|newsletters/unsubscribe)/[^"']+(["'])}i

  def prepare_preview_html(html)
    html
      .gsub(%r{<img src="https?://example.org}, "<img src=\"#{Current.org.members_url}\"")
      .gsub(/<a\s/, '<a target="_blank" rel="noopener noreferrer" ')
  end

  def redact_sensitive_urls(html)
    html.to_s.gsub(SENSITIVE_HREF) { "#{$1}#{preview_login_url}#{$2}" }
  end

  def preview_login_url
    "#{Current.org.members_url}/login"
  end

  def extract_html_content(message)
    if message.multipart?
      message.html_part&.body&.decoded
    else
      message.body.decoded
    end
  end
end
