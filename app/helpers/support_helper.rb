# frozen_string_literal: true

module SupportHelper
  def ticket_priorities_collection
    Support::Ticket.priorities.keys.map do |priority|
      [ t("support.ticket.priority.#{priority}"), priority ]
    end
  end
end
