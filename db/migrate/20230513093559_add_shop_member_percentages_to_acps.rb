class AddShopMemberPercentagesToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :shop_member_percentages, :decimal, precision: 8, scale: 2, default: [], null: false, array: true
  end
end
