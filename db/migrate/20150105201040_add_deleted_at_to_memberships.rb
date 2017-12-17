class AddDeletedAtToMemberships < ActiveRecord::Migration[4.2]
  def change
    add_column :memberships, :deleted_at, :datetime
    add_index :memberships, :deleted_at
  end
end
