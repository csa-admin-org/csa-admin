class RemoveBasketComplementsPriceType < ActiveRecord::Migration[7.1]
  def change
    remove_column :basket_complements, :price_type, :string, default: 'delivery', null: false
  end
end
