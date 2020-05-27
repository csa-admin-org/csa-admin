class RemoveWelcomeEmailSentAtFromMembers < ActiveRecord::Migration[6.0]
  def change
    remove_column :members, :welcome_email_sent_at
  end
end
