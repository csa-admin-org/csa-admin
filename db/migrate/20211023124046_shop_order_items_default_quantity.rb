class ShopOrderItemsDefaultQuantity < ActiveRecord::Migration[6.1]
  def change
    change_column_default :shop_order_items, :quantity, 0
  end
end
