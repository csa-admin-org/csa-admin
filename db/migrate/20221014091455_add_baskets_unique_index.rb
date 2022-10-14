class AddBasketsUniqueIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :baskets, %i[delivery_id membership_id], unique: true
  end
end
