class AddACPShares < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :share_price, :decimal, precision: 8, scale: 2
    add_column :invoices, :acp_shares_number, :integer
  end
end
