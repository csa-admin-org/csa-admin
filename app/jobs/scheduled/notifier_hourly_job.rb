# frozen_string_literal: true

module Scheduled
  class NotifierHourlyJob < BaseJob
    NOTIFICATIONS = [
      Notification::AdminNewActivityParticipation
    ].freeze

    def perform
      NOTIFICATIONS.each(&:notify_later)
    end
  end
end
