class AddBasketComplementsAnnualPriceChangeToMemberships < ActiveRecord::Migration[5.2]
  def change
    add_column :memberships, :basket_complements_annual_price_change, :decimal, precision: 8, scale: 2, default: 0, null: false
  end
end
