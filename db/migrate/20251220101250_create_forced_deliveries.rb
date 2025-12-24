# frozen_string_literal: true

class CreateForcedDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :forced_deliveries do |t|
      t.references :membership, null: false, foreign_key: true
      t.references :delivery, null: false, foreign_key: true
      t.timestamps
    end

    add_index :forced_deliveries, [ :membership_id, :delivery_id ], unique: true
  end
end
