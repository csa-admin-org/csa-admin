class AddBasketPriceExtraDynamicPricingToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :basket_price_extra_dynamic_pricing, :text
  end
end
