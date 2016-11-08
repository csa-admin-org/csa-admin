class AddAttachmentToGribouilles < ActiveRecord::Migration
  def change
    add_column :gribouilles, :attachment, :oid
    add_column :gribouilles, :attachment_name, :string
    add_column :gribouilles, :attachment_mime_type, :string
  end
end
