class RenameBasketPriceOnDistributions < ActiveRecord::Migration[5.1]
  def change
    rename_column :distributions, :basket_price, :price
  end
end
