# frozen_string_literal: true

class CreateDemoPageVisits < ActiveRecord::Migration[8.1]
  class Admin < ActiveRecord::Base; end

  def up
    add_column :admins, :demo_message, :text
    add_column :admins, :demo_registration_notification_sent_at, :datetime

    Admin.reset_column_information
    Admin.update_all("demo_registration_notification_sent_at = COALESCE(created_at, CURRENT_TIMESTAMP)")

    create_table :demo_page_visits do |t|
      t.references :admin, null: false, foreign_key: true
      t.references :session, null: false, foreign_key: true
      t.string :path, null: false
      t.string :controller_name, null: false
      t.string :action_name, null: false
      t.string :page_key, null: false
      t.integer :status, null: false
      t.timestamps
    end

    add_index :demo_page_visits, [ :admin_id, :created_at ]
    add_index :demo_page_visits, [ :session_id, :created_at ]
    add_index :demo_page_visits, [ :page_key, :created_at ]
    add_index :demo_page_visits, [ :admin_id, :page_key ]
  end

  def down
    drop_table :demo_page_visits
    remove_column :admins, :demo_registration_notification_sent_at
    remove_column :admins, :demo_message
  end
end
