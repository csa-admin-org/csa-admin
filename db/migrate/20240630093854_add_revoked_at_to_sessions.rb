class AddRevokedAtToSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :sessions, :revoked_at, :datetime
  end
end
