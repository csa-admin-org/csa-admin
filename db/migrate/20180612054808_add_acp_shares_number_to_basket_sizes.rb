class AddACPSharesNumberToBasketSizes < ActiveRecord::Migration[5.2]
  def change
    add_column :basket_sizes, :acp_shares_number, :integer
  end
end
