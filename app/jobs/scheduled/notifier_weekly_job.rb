# frozen_string_literal: true

module Scheduled
  class NotifierWeeklyJob < BaseJob
    NOTIFICATIONS = [
      Notification::BasketComplementWeeklySummary
    ].freeze

    def perform
      NOTIFICATIONS.each(&:notify_later)
    end
  end
end
