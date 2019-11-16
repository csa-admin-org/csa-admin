class AddGroupBuyingSettingsToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :group_buying_email, :string
    add_column :acps, :group_buying_terms_of_service_urls, :jsonb, default: {}, null: false
  end
end
