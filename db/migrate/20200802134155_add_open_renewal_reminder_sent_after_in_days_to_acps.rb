class AddOpenRenewalReminderSentAfterInDaysToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :open_renewal_reminder_sent_after_in_days, :integer
  end
end
