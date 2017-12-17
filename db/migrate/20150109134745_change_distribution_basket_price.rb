class ChangeDistributionBasketPrice < ActiveRecord::Migration[4.2]
  def change
    change_column :memberships, :distribution_basket_price, :decimal, scale: 2, precision: 8
  end
end
