class AddDisplayInDeliverySheetsToShopProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :shop_products, :display_in_delivery_sheets, :boolean, default: false, null: false
  end
end
