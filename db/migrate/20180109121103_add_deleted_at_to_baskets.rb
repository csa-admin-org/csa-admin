class AddDeletedAtToBaskets < ActiveRecord::Migration[5.2]
  def change
    add_column :baskets, :deleted_at, :timestamp
  end
end
