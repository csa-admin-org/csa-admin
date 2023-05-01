class AddPercentageToInvoices < ActiveRecord::Migration[7.0]
  def change
    add_column :invoices, :amount_percentage, :decimal, precision: 8, scale: 2
    add_column :invoices, :amount_before_percentage, :decimal, precision: 8, scale: 2
  end
end
