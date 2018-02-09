class RemoveDefaultPricesOnBaskets < ActiveRecord::Migration[5.2]
  def change
    change_column_default :baskets, :basket_price, nil
    change_column_default :baskets, :distribution_price, nil
  end
end
