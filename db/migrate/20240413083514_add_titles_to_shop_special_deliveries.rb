class AddTitlesToShopSpecialDeliveries < ActiveRecord::Migration[7.1]
  def change
    add_column :shop_special_deliveries, :titles, :jsonb, default: {}
  end
end
