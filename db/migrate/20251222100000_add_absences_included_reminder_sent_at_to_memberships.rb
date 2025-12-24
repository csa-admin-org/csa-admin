# frozen_string_literal: true

class AddAbsencesIncludedReminderSentAtToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :absences_included_reminder_sent_at, :datetime
  end
end
