class AddBasketPriceExtraToMemberships < ActiveRecord::Migration[6.0]
  def change
    add_column :memberships, :basket_price_extra, :decimal, scale: 2, precision: 8, default: 0, null: false
    add_column :members, :waiting_basket_price_extra, :decimal, scale: 2, precision: 8
  end
end
