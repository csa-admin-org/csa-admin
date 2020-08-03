class AddRenewalReminderSentAtToMemberships < ActiveRecord::Migration[6.0]
  def change
    add_column :memberships, :renewal_reminder_sent_at, :datetime
  end
end
