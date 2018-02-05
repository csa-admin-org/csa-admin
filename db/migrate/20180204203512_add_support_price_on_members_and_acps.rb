class AddSupportPriceOnMembersAndAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :support_price, :decimal, precision: 8, scale: 2, default: 0, null: false
    add_column :members, :support_price, :decimal, precision: 8, scale: 2, default: 0, null: false

    change_column_default :members, :support_price, nil
  end
end
