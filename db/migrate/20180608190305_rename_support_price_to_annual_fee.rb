class RenameSupportPriceToAnnualFee < ActiveRecord::Migration[5.2]
  def change
    rename_column :members, :support_price, :annual_fee
    rename_column :acps, :support_price, :annual_fee
  end
end
