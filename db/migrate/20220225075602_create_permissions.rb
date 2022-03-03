class CreatePermissions < ActiveRecord::Migration[6.1]
  def change
    create_table :permissions do |t|
      t.jsonb :names, default: {}, null: false
      t.jsonb :rights, default: {}, null: false
      t.timestamps
    end

    add_reference :admins, :permission, foreign_key: true, index: true
  end
end
