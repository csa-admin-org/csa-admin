class RemoveCarrierwaveColumns < ActiveRecord::Migration[5.2]
  def change
    remove_column :invoices, :pdf
    remove_column :gribouilles, :attachment_0
    remove_column :gribouilles, :attachment_name_0
    remove_column :gribouilles, :attachment_mime_type_0
    remove_column :gribouilles, :attachment_1
    remove_column :gribouilles, :attachment_name_1
    remove_column :gribouilles, :attachment_mime_type_1
    remove_column :gribouilles, :attachment_2
    remove_column :gribouilles, :attachment_name_2
    remove_column :gribouilles, :attachment_mime_type_2
  end
end
