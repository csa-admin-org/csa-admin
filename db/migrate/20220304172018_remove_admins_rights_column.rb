class RemoveAdminsRightsColumn < ActiveRecord::Migration[6.1]
  def change
    remove_column :admins, :rights, :string, default: 'standard'
    change_column_null :admins, :permission_id, false
  end
end
