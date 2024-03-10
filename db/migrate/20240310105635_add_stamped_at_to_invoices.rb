class AddStampedAtToInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :invoices, :stamped_at, :datetime
  end
end
