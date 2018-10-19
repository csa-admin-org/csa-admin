class AddLogoUrlToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :logo_url, :string
  end
end
