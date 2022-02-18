class AddBasketPriceExtraPublicTitlesToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :basket_price_extra_public_titles, :jsonb, default: {}, null: false
  end
end
