# frozen_string_literal: true

require "nokogiri"

class SupportMailer < ApplicationMailer
  layout "support_mailer"
  default from: -> { default_from }

  def wrap_email
    setup_message
    recipients = @ticket.wrap_emails_for(@message)
    return if recipients.empty?

    I18n.with_locale(wrap_locale) do
      @header = nil
      @reply_marker = true
      @previous = @message.previous
      attach_files
      sign_wrap!
      quote_previous!
      mail(
        from: @ticket.inbound_address,
        reply_to: @ticket.inbound_email,
        to: recipients,
        subject: reply_subject,
        tag: "support-ticket",
        message_stream: "outbound",
        **thread_headers)
    end
  end

  def ping_email
    setup_message
    return if @ticket.ping_address.blank?

    I18n.with_locale(ping_locale) do
      @header = ping_header
      @reply_marker = false
      attach_files
      @context_footer = "\n\n----\n#{@ticket.context}" if @ticket.context.present?
      mail(
        from: @ticket.ping_from,
        reply_to: @ticket.inbound_email,
        to: @ticket.ping_address,
        subject: @ticket.subject_decorated,
        tag: "support-ticket",
        message_stream: "outbound",
        **thread_headers)
    end
  end

  private

  def setup_message
    @message = params[:message]
    @ticket = @message.ticket
  end

  def default_from
    @ticket&.inbound_address || super
  end

  def default_url_options
    Tenant.local_url_options(Tenant.admin_host)
  end

  def set_postmark_server_token
    return unless @_message.is_a?(Mail::Message)

    mail.delivery_method.settings[:api_token] = Support::Ticket.postmark_server_token
  end

  def wrap_locale
    @ticket.admin&.language.presence || Current.org.languages.first
  end

  def ping_locale
    ENV.fetch("ULTRA_ADMIN_LANGUAGE", I18n.default_locale)
  end

  def ping_header
    t("support.mailer.ping.header",
      tenant: Tenant.current,
      org: Current.org.name,
      author: @message.display_name)
  end

  def reply_subject
    subject = @ticket.subject_decorated
    subject.start_with?("Re:") ? subject : "Re: #{subject}"
  end

  def thread_headers
    headers = { "Message-ID" => @message.ensure_rfc_message_id! }
    if (previous = @message.previous&.rfc_message_id)
      headers["In-Reply-To"] = previous
      headers["References"] = previous
    end
    headers
  end

  def attach_files
    @content = email_html if @message.html.present?
    @body = @message.body
    @message.attachments.map(&:file).each { |file|
      attach_blob(file.blob) if file.attached?
    }
  end

  def quote_previous!
    return unless @previous

    @quoted_header = "#{@previous.display_name}, #{I18n.l(@previous.created_at, format: :short)}:"
    @quoted_text = "\n\n#{@quoted_header}\n#{@previous.body.to_s.gsub(/^/, "> ")}"
    @quoted_html = if @previous.html.present?
      ActionTextHtml.unwrap_attachments(@previous.html.to_s).html_safe
    else
      ApplicationController.helpers.simple_format(@previous.body)
    end
  end

  def sign_wrap!
    return unless @message.author_support?

    unsigned = @body
    @body = Support::Signature.append_text(@body)
    html = @content.presence || ApplicationController.helpers.simple_format(unsigned)
    @content = Support::Signature.append_html(html).html_safe
  end

  def email_html
    html = ActionTextHtml.unwrap_attachments(@message.html.to_s)
    html = embed_inline_images(html)
    html.html_safe
  end

  def embed_inline_images(html)
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.css("img").each do |img|
      blob = blob_from_src(img["src"])
      next unless blob

      attachments.inline[blob.filename.to_s] = {
        mime_type: blob.content_type,
        content: blob.download
      }
      img["src"] = attachments[blob.filename.to_s].url
    end
    doc.to_html
  end

  def blob_from_src(src)
    return if src.blank?
    return unless src.start_with?("http", "/")

    signed = src[%r{/rails/active_storage/blobs/(?:redirect/|proxy/)?([^/]+)}, 1]
    ActiveStorage::Blob.find_signed(signed) if signed
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def attach_blob(blob)
    filename = ActiveSupport::Inflector.transliterate(blob.filename.to_s.gsub(/"/, "'"))
    attachments[filename] = {
      mime_type: blob.content_type,
      content: blob.download
    }
  end
end
