# frozen_string_literal: true

class SupportMailer < ApplicationMailer
  def ticket_email
    @ticket = params[:ticket]
    attach_attachments!
    mail(
      to: Admin.ultra.email,
      reply_to: email_address_with_name(@ticket.admin.email, @ticket.admin.name),
      cc: @ticket.emails_array,
      subject: @ticket.subject_decorated)
  end

  private

  def attach_attachments!
    @ticket.attachments.map(&:file).each { |file|
      filename =
        ActiveSupport::Inflector.transliterate(file.filename.to_s.gsub(/"/, "'"))
      attachments[filename] = {
        mime_type: file.content_type,
        content: file.download
      }
    }
  end
end
