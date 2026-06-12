# frozen_string_literal: true

class AddCapToOrganizationsAndDropActiveHashcashStamps < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :cap_site_key, :string
    add_column :organizations, :cap_secret_key, :string

    drop_table :active_hashcash_stamps, if_exists: true do |t|
      t.string :version, null: false
      t.integer :bits, null: false
      t.date :date, null: false
      t.string :resource, null: false
      t.string :ext, null: false
      t.string :rand, null: false
      t.string :counter, null: false
      t.string :request_path
      t.string :ip_address
      t.json :context
      t.timestamps

      t.index [ :ip_address, :created_at ], where: "ip_address IS NOT NULL"
      t.index [ :counter, :rand, :date, :resource, :bits, :version, :ext ],
        name: "index_active_hashcash_stamps_unique",
        unique: true
    end
  end
end
