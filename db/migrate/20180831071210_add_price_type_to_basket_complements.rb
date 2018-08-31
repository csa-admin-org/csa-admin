class AddPriceTypeToBasketComplements < ActiveRecord::Migration[5.2]
  def change
    add_column :basket_complements, :price_type, :string, default: 'delivery', null: false
  end
end
