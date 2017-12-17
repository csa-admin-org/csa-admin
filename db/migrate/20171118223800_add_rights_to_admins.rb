class AddRightsToAdmins < ActiveRecord::Migration[5.1]
  def change
    add_column :admins, :rights, :string, null: false, default: 'standard'
  end
end
