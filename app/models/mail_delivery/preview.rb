# frozen_string_literal: true

# Handles preview storage and rendering for MailDelivery.
#
# After ProcessJob delivers the first email for a MailDelivery, it calls
# `store_preview_from!` to extract and cache the rendered subject + HTML
# content. This cached content is then used by `mail_preview` to render
# previews in admin and member-facing views.
module MailDelivery::Preview
  extend ActiveSupport::Concern

  # Idempotent: only stores once per email delivery (first email wins).
  def store_preview_from!(message)
    return if self.subject.present?

    update!(
      subject: message.subject,
      content: extract_html_content(message))
  end

  # Handles both new format (full HTML) and legacy format (Liquid body).
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
