# frozen_string_literal: true

module Support
  class Ticket < ApplicationRecord
    self.table_name = "support_tickets"
    class HighPriorityTicket < StandardError; end

    PRIORITY_ICONS = { medium: "❗️", high: "‼️" }

    include HasAttachments
    include HasEmails

    enum :priority, %i[normal medium high]

    belongs_to :admin

    validates :subject, presence: true
    validates :content, presence: true

    after_commit :notify, on: :create

    def subject_decorated
      "🛟#{PRIORITY_ICONS[priority.to_sym]} #{subject}"
    end

    private

    def notify
      SupportMailer.with(ticket: self).ticket_email.deliver_later(wait: 10.seconds)
      Error.report(HighPriorityTicket.new("High priority support ticket")) if high?
    end
  end
end
