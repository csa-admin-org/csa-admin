class RenameInvoicesObjectToEntity < ActiveRecord::Migration[7.0]
  def change
    rename_column :invoices, :object_id, :entity_id
    rename_column :invoices, :object_type, :entity_type
  end
end
