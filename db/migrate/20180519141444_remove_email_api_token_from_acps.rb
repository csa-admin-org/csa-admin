class RemoveEmailApiTokenFromAcps < ActiveRecord::Migration[5.2]
  def change
    remove_column :acps, :email_api_token
  end
end
