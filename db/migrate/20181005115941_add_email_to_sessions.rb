class AddEmailToSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :sessions, :email, :string
  end
end
