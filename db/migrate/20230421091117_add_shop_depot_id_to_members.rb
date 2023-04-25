class AddShopDepotIdToMembers < ActiveRecord::Migration[7.0]
  def change
    add_reference :members, :shop_depot, foreign_key: { to_table: :depots }, index: true
  end
end
