class AddDeletedAtToMemberships < ActiveRecord::Migration
  def change
    add_column :memberships, :deleted_at, :datetime
    add_index :memberships, :deleted_at
  end
end
