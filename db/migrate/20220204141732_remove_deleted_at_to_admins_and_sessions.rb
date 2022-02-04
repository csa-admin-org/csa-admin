class RemoveDeletedAtToAdminsAndSessions < ActiveRecord::Migration[6.1]
  def change
    execute 'DELETE FROM sessions WHERE deleted_at IS NOT NULL'
    remove_column :sessions, :deleted_at

    execute 'DELETE FROM admins WHERE deleted_at IS NOT NULL'
    remove_column :admins, :deleted_at
  end
end
