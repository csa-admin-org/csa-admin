# frozen_string_literal: true

require "base64"

module Support
  class Message < ApplicationRecord
    self.table_name = "support_messages"

    include HasAttachments
    has_rich_text :html

    enum :author, { admin: "admin", support: "support" }, prefix: true

    belongs_to :ticket, class_name: "Support::Ticket", inverse_of: :messages,
      touch: true
    belongs_to :admin, optional: true

    validates :body, presence: true
    validates :rfc_message_id, uniqueness: true, allow_nil: true

    before_validation :sync_body_from_html, :assign_admin_name
    after_create :bump_ticket_last_activity
    after_commit :notify, on: :create

    attr_accessor :skip_notify

    def via
      @via || :app
    end

    def via=(value)
      @via = value&.to_sym
    end

    def hop_email
      if author_admin?
        admin&.email
      else
        ENV["SUPPORT_EMAIL"].presence || ENV["ULTRA_ADMIN_EMAIL"]
      end
    end

    def display_name
      if author_support?
        ENV.fetch("ULTRA_ADMIN_NAME", "CSA Admin")
      else
        admin_name.presence || I18n.t("active_admin.unknown")
      end
    end

    def unknown_author?
      author_admin? && admin_name.blank?
    end

    def previous
      ticket.messages.where("id < ?", id).order(id: :desc).first
    end

    def opening?
      ticket.messages.where("id < ?", id).none?
    end

    def wrap?
      return false if Tenant.demo?

      ticket.wrap_emails_for(self).any?
    end

    def ping?
      return false if Tenant.demo?
      return false if via == :inbound && author_support?

      ticket.ping_address.present?
    end

    def attach_inbound(raw_attachments, html: nil)
      leftover, cid_blobs = Support::InboundAttachments.split(raw_attachments, html: html)
      if html.present? && cid_blobs.any?
        html = Support::InboundAttachments.rewrite_cids(html, cid_blobs)
      end
      leftover.each { |decoded, raw| attach_decoded(decoded, raw) }
      html
    end

    def ensure_rfc_message_id!
      return rfc_message_id if rfc_message_id.present?

      generated = "<#{ticket.token}.#{id || "preview"}.#{SecureRandom.hex(4)}@#{Support::Ticket::INBOUND_DOMAIN}>"
      if persisted?
        update_column(:rfc_message_id, generated)
      else
        self.rfc_message_id = generated
      end
      rfc_message_id
    end

    private

    def sync_body_from_html
      return if html.blank?

      self.body = html.to_plain_text.presence || body
    end

    def assign_admin_name
      return unless author_admin?
      return if admin.blank?

      self.admin_name = admin.name
    end

    def bump_ticket_last_activity
      ticket.bump_last_activity!(created_at)
    end

    def attach_decoded(decoded, raw)
      file = attachments.build
      file.file.attach(
        io: StringIO.new(decoded),
        filename: raw["Name"].presence || "attachment",
        content_type: raw["ContentType"].presence || "application/octet-stream")
    end

    def notify
      return if Tenant.demo?
      return if skip_notify

      ensure_rfc_message_id!
      SupportMailer.with(message: self).wrap_email.deliver_later if wrap?
      SupportMailer.with(message: self).ping_email.deliver_later if ping?
      Support::MessageNotifyJob.perform_later(self) if Support::Ticket.webhook_url
    end
  end
end
