class AddVatColumnsToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :vat_number, :string
    add_column :acps, :vat_membership_rate, :decimal, scale: 2, precision: 8
  end
end
