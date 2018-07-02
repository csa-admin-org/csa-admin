class CreateSessions < ActiveRecord::Migration[5.1]
  def change
    create_table :sessions do |t|
      t.belongs_to :member, foreign_key: true, index: true
      t.string :token, null: false

      t.text :user_agent, null: false
      t.string :remote_addr, null: false

      t.timestamps
    end

    add_index :sessions, :token, unique: true
  end
end
