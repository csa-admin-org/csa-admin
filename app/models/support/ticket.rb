# frozen_string_literal: true

module Support
  class Ticket < ApplicationRecord
    self.table_name = "support_tickets"
    class HighPriorityTicket < StandardError; end

    PRIORITY_ICONS = { medium: "❗️", high: "‼️" }

    include HasAttachments
    include HasEmails

    enum :priority, %i[normal medium high]

    belongs_to :admin, optional: true

    validates :subject, presence: true
    validates :content, presence: true

    after_commit :notify, on: :create

    def subject_decorated
      "🛟#{PRIORITY_ICONS[priority.to_sym]} #{subject}"
    end

    class << self
      def webhook_url
        Rails.application.credentials.dig(:support_ticket_webhook, :url).presence
      end

      def webhook_authorization
        value = Rails.application.credentials.dig(:support_ticket_webhook, :authorization).presence
        return unless value

        value.start_with?("Bearer ") ? value : "Bearer #{value}"
      end
    end

    private

    def notify
      SupportMailer.with(ticket: self).ticket_email.deliver_later(wait: 10.seconds)
      Support::TicketNotifyJob.set(wait: 10.seconds).perform_later(self) if self.class.webhook_url
      Rails.error.report(HighPriorityTicket.new("High priority support ticket")) if high?
    end
  end
end
