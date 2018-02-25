class AddMemberPageColumnsToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :email, :string
    add_column :acps, :phone, :string
    add_column :acps, :url, :string
  end
end
