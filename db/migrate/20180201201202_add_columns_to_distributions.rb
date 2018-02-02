class AddColumnsToDistributions < ActiveRecord::Migration[5.2]
  def change
    add_column :distributions, :address_name, :string
    add_column :distributions, :phones, :string
    add_column :distributions, :note, :text
  end
end
