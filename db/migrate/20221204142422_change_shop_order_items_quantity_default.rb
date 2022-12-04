class ChangeShopOrderItemsQuantityDefault < ActiveRecord::Migration[7.0]
  def change
    change_column_default :shop_order_items, :quantity, 1
  end
end
