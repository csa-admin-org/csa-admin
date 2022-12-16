class AddACPBasketUpdateSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :basket_update_limit_in_days, :integer, default: 0, null: false
    add_column :acps, :membership_depot_update_allowed, :boolean, default: false, null: false
  end
end
