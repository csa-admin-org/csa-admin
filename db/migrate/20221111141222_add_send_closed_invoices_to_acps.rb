class AddSendClosedInvoicesToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :send_closed_invoice, :boolean, default: false, null: false
  end
end
