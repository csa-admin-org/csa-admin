class AddOverpaidNotificationSentAtToInvoices < ActiveRecord::Migration[6.0]
  def change
    add_column :invoices, :overpaid_notification_sent_at, :datetime
  end
end
