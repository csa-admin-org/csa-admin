class RemoveDevise < ActiveRecord::Migration[5.2]
  def change
    remove_column :admins, :encrypted_password
    remove_column :admins, :reset_password_token
    remove_column :admins, :reset_password_sent_at
    remove_column :admins, :remember_created_at
    remove_column :admins, :sign_in_count
    remove_column :admins, :current_sign_in_at
    remove_column :admins, :last_sign_in_at
    remove_column :admins, :current_sign_in_ip
    remove_column :admins, :last_sign_in_ip
  end
end
