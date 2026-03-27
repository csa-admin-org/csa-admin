# frozen_string_literal: true

module Scheduled
  class NotifierHourlyJob < BaseJob
    NOTIFICATIONS = [
      Notification::AdminNewAbsence,
      Notification::AdminNewActivityParticipation,
      Notification::DemoFollowUp
    ].freeze

    def perform
      NOTIFICATIONS.each(&:notify_later)
    end
  end
end
