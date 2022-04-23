class AddBasketContentsUnitPrice < ActiveRecord::Migration[7.0]
  def change
    add_column :basket_contents, :unit_price, :decimal, precision: 8, scale: 2, default: nil
    add_column :deliveries, :basket_content_avg_prices, :jsonb, default: {}
  end
end
