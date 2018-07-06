class AddLastUsageColumnsToSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :sessions, :last_used_at, :timestamp
    add_column :sessions, :last_remote_addr, :string
    add_column :sessions, :last_user_agent, :string
  end
end
