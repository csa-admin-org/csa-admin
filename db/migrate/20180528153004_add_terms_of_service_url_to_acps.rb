class AddTermsOfServiceUrlToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :terms_of_service_url, :string
  end
end
