class AddMoreShopSettingsToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :shop_terms_of_sale_urls, :jsonb, default: {}, null: false
  end
end
