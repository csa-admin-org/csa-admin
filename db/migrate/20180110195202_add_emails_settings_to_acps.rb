class AddEmailsSettingsToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :email_api_token, :string
    add_column :acps, :email_default_host, :string
    add_column :acps, :email_default_from, :string
  end
end
