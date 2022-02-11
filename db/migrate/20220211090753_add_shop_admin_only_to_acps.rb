class AddShopAdminOnlyToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :shop_admin_only, :boolean, default: true, null: false
  end
end
