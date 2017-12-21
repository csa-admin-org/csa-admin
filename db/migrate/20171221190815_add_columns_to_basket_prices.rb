class AddColumnsToBasketPrices < ActiveRecord::Migration[5.1]
  def change
    add_column :basket_sizes, :price, :decimal, scale: 3, precision: 8, default: 0, null: false
    remove_column :basket_sizes, :annual_price
    add_column :basket_sizes, :annual_halfday_works, :integer, default: 0, null: false

    add_index :basket_sizes, :name, unique: true
  end
end
