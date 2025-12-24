# frozen_string_literal: true

module Scheduled
  class AbsencesIncludedReminderJob < BaseJob
    def perform
      Membership.send_absences_included_reminders
    end
  end
end
