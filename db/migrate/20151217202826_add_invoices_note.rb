class AddInvoicesNote < ActiveRecord::Migration[4.2]
  def change
    add_column :invoices, :note, :text
  end
end
