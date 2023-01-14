class AddMoreVat < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :vat_activity_rate, :decimal, precision: 8, scale: 2
    add_column :acps, :vat_shop_rate, :decimal, precision: 8, scale: 2

    rename_column :invoices, :memberships_vat_amount, :vat_amount
    add_column :invoices, :vat_rate, :decimal, precision: 8, scale: 2
  end
end
