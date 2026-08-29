# frozen_string_literal: true

class Support::Ticket::WebhookPayload
  ATTACHMENT_URL_EXPIRES_IN = 7.days

  def initialize(ticket)
    @ticket = ticket
  end

  def as_json(*)
    {
      "event" => "support.ticket.created",
      "tenant" => Tenant.current,
      "ticket" => ticket_json,
      "admin" => admin_json,
      "org" => org_json,
      "cc_emails" => ticket.emails_array,
      "attachment_urls" => attachment_urls,
      "app" => app_json
    }
  end

  private

  attr_reader :ticket

  def ticket_json
    {
      "id" => ticket.id,
      "subject" => ticket.subject,
      "content" => ticket.content,
      "context" => ticket.context,
      "priority" => ticket.priority,
      "created_at" => ticket.created_at&.iso8601
    }
  end

  def admin_json
    admin = ticket.admin
    return unless admin

    {
      "id" => admin.id,
      "name" => admin.name,
      "email" => admin.email,
      "language" => admin.language
    }
  end

  def org_json
    org = Current.org

    {
      "name" => org.name,
      "admin_host" => Tenant.admin_host,
      "members_host" => Tenant.members_host,
      "email" => org.email,
      "languages" => org.languages,
      "features" => org.features.map(&:to_s)
    }
  end

  def app_json
    {
      "revision" => ENV["GIT_REV"].presence,
      "locale" => I18n.locale.to_s
    }
  end

  def attachment_urls
    blobs = ticket.attachments.filter_map { |attachment|
      attachment.file.blob if attachment.file.attached?
    }
    return [] if blobs.empty?

    blobs.map { |blob|
      Rails.application.routes.url_helpers.rails_blob_url(
        blob,
        host: Tenant.admin_host,
        protocol: "https",
        expires_in: ATTACHMENT_URL_EXPIRES_IN)
    }
  end
end
