class AddDeletedAtToSessions < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :deleted_at, :datetime
  end
end
