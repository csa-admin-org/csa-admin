class AddLatestReminderSentAtToHalfdayParticipations < ActiveRecord::Migration[5.2]
  def change
    add_column :halfday_participations, :latest_reminder_sent_at, :timestamp
  end
end
