class FixSoftDeletableIndexes < ActiveRecord::Migration[6.0]
  def change
    remove_index :baskets, [ :membership_id, :delivery_id ]
    add_index :baskets, [ :membership_id, :delivery_id ], unique: true, where: 'deleted_at IS NULL'
  end
end
