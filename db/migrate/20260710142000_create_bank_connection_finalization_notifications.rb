# frozen_string_literal: true

class CreateBankConnectionFinalizationNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_connection_finalization_notifications do |t|
      t.references :bank_connection, null: false, foreign_key: { on_delete: :cascade }
      t.string :event_id, null: false
      t.string :recipient, null: false
      t.string :state, null: false, default: "pending"

      t.datetime :delivery_started_at
      t.datetime :delivered_at
      t.string :delivery_claim_token
      t.string :last_error_class
      t.timestamps
    end

    add_index :bank_connection_finalization_notifications,
      [ :bank_connection_id, :event_id, :recipient ],
      unique: true,
      name: "index_unique_bank_connection_finalization_notifications"
    add_index :bank_connection_finalization_notifications, :state
    add_check_constraint :bank_connection_finalization_notifications,
      "recipient IN ('initiating_admin', 'ultra_admin')",
      name: "bank_connection_finalization_notifications_recipient"
    add_check_constraint :bank_connection_finalization_notifications,
      "state IN ('pending', 'delivering', 'delivered', 'skipped')",
      name: "bank_connection_finalization_notifications_state"
  end
end
