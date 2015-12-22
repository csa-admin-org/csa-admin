class AddMemberBillingIntervalToInvoices < ActiveRecord::Migration
  def change
    add_column :invoices, :member_billing_interval, :string, null: false
  end
end
