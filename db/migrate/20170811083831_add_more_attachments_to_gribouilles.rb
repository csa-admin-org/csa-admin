class AddMoreAttachmentsToGribouilles < ActiveRecord::Migration[5.1]
  def change
    rename_column :gribouilles, :attachment, :attachment_0
    rename_column :gribouilles, :attachment_name, :attachment_name_0
    rename_column :gribouilles, :attachment_mime_type, :attachment_mime_type_0

    add_column :gribouilles, :attachment_1, :oid
    add_column :gribouilles, :attachment_name_1, :string
    add_column :gribouilles, :attachment_mime_type_1, :string

    add_column :gribouilles, :attachment_2, :oid
    add_column :gribouilles, :attachment_name_2, :string
    add_column :gribouilles, :attachment_mime_type_2, :string
  end
end
