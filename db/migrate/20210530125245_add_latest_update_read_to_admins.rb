class AddLatestUpdateReadToAdmins < ActiveRecord::Migration[6.1]
  def change
    add_column :admins, :latest_update_read, :string
  end
end
