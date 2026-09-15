# frozen_string_literal: true

module Support
  class Ticket < ApplicationRecord
    self.table_name = "support_tickets"

    PRIORITY_ICONS = { medium: "❗️", high: "‼️" }
    INBOUND_DOMAIN = "support.csa-admin.org"

    include HasAttachments
    has_rich_text :html

    enum :priority, %i[normal medium high], validate: true

    belongs_to :admin, optional: true
    has_many :messages, class_name: "Support::Message",
      foreign_key: :ticket_id, dependent: :destroy, inverse_of: :ticket
    has_one :last_message, -> { order(id: :desc) },
      class_name: "Support::Message", foreign_key: :ticket_id

    scope :waiting, -> {
      where(<<~SQL.squish)
        #{last_message_sql(:author)} = 'admin'
        AND (
          support_tickets.replied_at IS NULL
          OR #{last_message_sql(:created_at)} > support_tickets.replied_at
        )
      SQL
    }
    scope :replied, -> {
      where(<<~SQL.squish)
        #{last_message_sql(:author)} = 'support'
        OR (
          support_tickets.replied_at IS NOT NULL
          AND #{last_message_sql(:created_at)} <= support_tickets.replied_at
        )
      SQL
    }
    scope :ordered_by_last_activity, -> { order(last_activity_at: :desc) }
    scope :last_activity_at_gteq, ->(date) {
      return all if date.blank?

      where(last_activity_at: date.to_date.beginning_of_day..)
    }
    scope :last_activity_at_lteq, ->(date) {
      return all if date.blank?

      where(last_activity_at: ..date.to_date.end_of_day)
    }
    scope :text_cont, ->(q) {
      return all if q.blank?

      pattern = "%#{sanitize_sql_like(q)}%"
      left_joins(messages: :rich_text_html).where(
        "support_tickets.subject LIKE :q OR support_messages.body LIKE :q OR action_text_rich_texts.body LIKE :q",
        q: pattern).distinct
    }

    def self.ransackable_scopes(_auth_object = nil)
      %i[text_cont last_activity_at_gteq last_activity_at_lteq]
    end

    attr_accessor :skip_opening_message

    validates :subject, presence: true
    validates :content, presence: true
    validates :token, presence: true, uniqueness: true,
      format: { with: /\A[0-9a-f]{8}\z/ }

    before_validation :assign_token, on: :create
    before_validation :assign_last_activity_at, on: :create
    before_validation :sync_content_from_html, on: :create
    after_create :ensure_opening_message

    def subject_decorated
      "🛟#{priority_mark} #{subject}"
    end

    def subject_with_priority
      mark = priority_mark
      mark ? "#{subject} #{mark}" : subject
    end

    def priority_mark
      PRIORITY_ICONS[priority.to_sym]
    end

    def to_param
      token
    end

    def display_title
      subject_with_priority
    end

    def state
      if waiting?
        "waiting"
      elsif replied?
        "replied"
      end
    end

    def context_path
      return if context.blank?

      uri = URI.parse(context)
      return context unless uri.is_a?(URI::HTTP) && uri.path.present?

      [ uri.path, uri.query ].compact.join("?")
    rescue URI::InvalidURIError
      context
    end

    def inbound_email
      "ticket-#{token}-#{Tenant.current}@#{INBOUND_DOMAIN}"
    end

    def inbound_address
      email_address_with_name(inbound_email, "CSA Admin")
    end

    def show_url
      Rails.application.routes.url_helpers.support_ticket_url(
        self,
        **Tenant.local_url_options(Tenant.admin_host))
    end

    def participants
      admins = []
      admins << admin if admin
      admins.concat(messages.where(author: "admin").filter_map(&:admin))
      admins.uniq
    end

    def wrap_emails_for(message)
      participants.filter_map(&:email).map(&:downcase).uniq -
        Array(message.hop_email&.downcase)
    end

    def ping_address
      ENV["SUPPORT_EMAIL"].presence
    end

    def ping_from
      email_address_with_name(
        "#{priority}@#{INBOUND_DOMAIN}",
        "CSA Admin 🛟#{priority_mark}")
    end

    def waiting?
      last_message&.author_admin? && !marked_as_replied?
    end

    def replied?
      last_message&.author_support? || marked_as_replied?
    end

    def marked_as_replied?
      replied_at.present? && last_message.present? && last_message.created_at <= replied_at
    end

    def mark_as_replied!(at: Time.current)
      attrs = { replied_at: at }
      attrs[:last_activity_at] = at if last_activity_at.blank? || last_activity_at < at
      update!(attrs)
    end

    def bump_last_activity!(at)
      return if last_activity_at && last_activity_at >= at

      update_column(:last_activity_at, at)
    end

    def self.ingest_inbound(payload, address)
      if address.convert?
        convert_inbound(payload)
      else
        ticket = find_by(token: address.token)
        return unless ticket

        ticket.append_inbound(payload)
      end
    end

    def self.convert_inbound(payload)
      return unless Support::InboundAddress.operator_email?(Support::InboundAddress.from_email(payload))

      rfc_id = Support::InboundAddress.message_id_from(payload)
      return if rfc_id.present? && Support::Message.exists?(rfc_message_id: rfc_id)

      html = Support::ReplyHtml.extract(payload["HtmlBody"], keep_cited: true)
      body = inbound_plain_body(payload, keep_cited: true)
      return if body.blank? && html.blank?

      original_email = Support::ReplyBody.original_from(payload["TextBody"])
      matched_admin = Admin.with_email(original_email).first if original_email

      ticket = new(
        subject: inbound_subject(payload["Subject"]),
        content: body.presence || ActionText::Content.new(html).to_plain_text,
        priority: :normal,
        admin: matched_admin,
        skip_opening_message: true)
      transaction do
        ticket.save!
        ticket.persist_inbound_message(
          author: "support",
          body: body,
          html: html,
          rfc_message_id: rfc_id,
          attachments: payload["Attachments"])
      end
      ticket
    end

    def append_inbound(payload)
      rfc_id = Support::InboundAddress.message_id_from(payload)
      return if rfc_id.present? && Support::Message.exists?(rfc_message_id: rfc_id)

      html = Support::ReplyHtml.extract(payload["HtmlBody"])
      body = self.class.inbound_plain_body(payload)
      return if body.blank? && html.blank?

      from = Support::InboundAddress.from_email(payload)
      author, admin = inbound_author(from)
      return unless author

      persist_inbound_message(
        author: author,
        admin: admin,
        body: body,
        html: html,
        rfc_message_id: rfc_id,
        attachments: payload["Attachments"])
    end

    def persist_inbound_message(author:, body:, rfc_message_id:, attachments: nil, admin: nil, html: nil)
      body = Support::Utf8.repair(body.to_s)
      html = Support::Utf8.repair(html.to_s).presence
      message = messages.build(
        author: author,
        admin: admin,
        body: body.presence || ActionText::Content.new(html.to_s).to_plain_text.presence || " ",
        via: :inbound,
        rfc_message_id: rfc_message_id)
      rewritten = message.attach_inbound(attachments, html: html)
      message.html = rewritten.presence || html if html.present? || rewritten.present?
      message.save!
      message
    end

    class << self
      def last_message_sql(column)
        unless column.in?(%i[author created_at])
          raise ArgumentError, "unsupported last message column: #{column}"
        end

        <<~SQL.squish
          (SELECT #{column} FROM support_messages
           WHERE support_messages.ticket_id = support_tickets.id
           ORDER BY id DESC LIMIT 1)
        SQL
      end

      def webhook_url
        Rails.application.credentials.dig(:support, :ticket_webhook, :url).presence
      end

      def webhook_authorization
        value = Rails.application.credentials.dig(:support, :ticket_webhook, :authorization).presence
        return unless value

        value.start_with?("Bearer ") ? value : "Bearer #{value}"
      end

      def postmark_server_token
        Rails.application.credentials.dig(:support, :postmark, :server_token).presence
      end

      def inbound_webhook_password
        Rails.application.credentials.dig(:support, :postmark, :inbound_webhook_password).presence
      end

      def inbound_subject(subject)
        cleaned = subject.to_s.sub(/\A(re|fwd|fw|tr|aw):\s*/i, "").strip
        cleaned.presence || "Support"
      end

      def inbound_plain_body(payload, keep_cited: false)
        Support::ReplyBody.extract(
          text_body: payload["TextBody"],
          stripped: payload["StrippedTextReply"],
          keep_cited: keep_cited)
      end
    end

    private

    def assign_last_activity_at
      self.last_activity_at ||= Time.current
    end

    def assign_token
      return if token.present?

      self.token = loop do
        candidate = SecureRandom.hex(4)
        break candidate unless self.class.exists?(token: candidate)
      end
    end

    def sync_content_from_html
      return if content.present? || html.blank?

      self.content = html.to_plain_text
    end

    def ensure_opening_message
      return if skip_opening_message
      return if messages.exists?

      files = attachments.to_a
      message = messages.build(
        author: "admin",
        admin: admin,
        body: content,
        via: :app)
      message.html = html.body if html.present?
      files.each { |attachment| attachment.attachable = message }
      message.attachments = files
      message.save!
      html.destroy if html.present?
      attachments.reset
    end

    def inbound_author(from)
      return unless from.present?

      if Support::InboundAddress.operator_email?(from)
        [ "support", nil ]
      elsif (matched = Admin.with_email(from).first)
        [ "admin", matched ]
      end
    end

    def email_address_with_name(email, name)
      ActionMailer::Base.email_address_with_name(email, name)
    end
  end
end
