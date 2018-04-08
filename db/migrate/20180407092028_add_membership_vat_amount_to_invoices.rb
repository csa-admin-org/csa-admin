class AddMembershipVatAmountToInvoices < ActiveRecord::Migration[5.2]
  def change
    add_column :invoices, :memberships_vat_amount, :decimal, scale: 2, precision: 8
  end
end
