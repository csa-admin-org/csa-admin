class AddPriceAndInvoicesAmountToMemberships < ActiveRecord::Migration[5.2]
  def change
    add_column :memberships, :price, :decimal, scale: 2, precision: 8
    add_column :memberships, :invoices_amount, :decimal, scale: 2, precision: 8
  end
end
