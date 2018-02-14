class AddInvoiceIsrColumnsToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :ccp, :string
    add_column :acps, :isr_identity, :string
    add_column :acps, :isr_payment_for, :text
    add_column :acps, :isr_in_favor_of, :text
    add_column :acps, :invoice_info, :text
    add_column :acps, :invoice_footer, :text
  end
end
