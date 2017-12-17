class AddMemberBillingIntervalToInvoices < ActiveRecord::Migration[4.2]
  def change
    add_column :invoices, :member_billing_interval, :string, null: false
  end
end
