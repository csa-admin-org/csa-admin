class AddPrivacyPolicyUrlsToAcps < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :privacy_policy_urls, :jsonb, default: {}, null: false
  end
end
