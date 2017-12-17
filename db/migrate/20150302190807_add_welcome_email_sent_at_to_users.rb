class AddWelcomeEmailSentAtToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :members, :welcome_email_sent_at, :datetime
    add_index :members, :welcome_email_sent_at
  end
end
