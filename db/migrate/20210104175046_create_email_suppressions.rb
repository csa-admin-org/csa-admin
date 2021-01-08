class CreateEmailSuppressions < ActiveRecord::Migration[6.1]
  def change
    create_table :email_suppressions do |t|
      t.string :email
      t.string :reason
      t.string :origin
      t.string :stream_id
      t.datetime :deleted_at
      t.datetime :created_at
    end

    add_index :email_suppressions, [:stream_id, :email, :reason, :origin, :created_at], unique: true, name: 'email_suppressions_unique_index'
  end
end
