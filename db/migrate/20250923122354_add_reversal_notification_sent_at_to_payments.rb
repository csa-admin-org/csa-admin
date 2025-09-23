# frozen_string_literal: true

class AddReversalNotificationSentAtToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :reversal_notification_sent_at, :datetime
  end
end
