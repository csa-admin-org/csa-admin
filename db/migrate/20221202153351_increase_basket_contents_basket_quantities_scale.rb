class IncreaseBasketContentsBasketQuantitiesScale < ActiveRecord::Migration[7.0]
  def change
    change_column :basket_contents, :basket_quantities, :decimal, precision: 8, scale: 3, default: [], array: true
  end
end
