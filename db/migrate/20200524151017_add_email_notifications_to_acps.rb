class AddEmailNotificationsToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :email_notifications, :string, array: true, default: [], null: false
  end
end
