class AddBasketComplementIdToShopProducts < ActiveRecord::Migration[6.1]
  def change
    add_reference :shop_products, :basket_complement,
      foreign_key: true,
      index: { unique: true }
  end
end
