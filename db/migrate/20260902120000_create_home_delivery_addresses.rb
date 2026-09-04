# frozen_string_literal: true

class CreateHomeDeliveryAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :home_delivery_addresses do |t|
      t.references :member, null: false, index: true
      t.references :session, index: true
      t.string :name, null: false
      t.string :street
      t.string :zip
      t.string :city
      t.string :note
      t.timestamps
    end

    create_table :home_delivery_address_deliveries do |t|
      t.references :home_delivery_address, null: false, index: true
      t.references :delivery, null: false, index: true
      t.references :member, null: false, index: true
      t.timestamps

      t.index [ :home_delivery_address_id, :delivery_id ],
        unique: true,
        name: "idx_hda_deliveries_on_address_and_delivery"
      t.index [ :member_id, :delivery_id ],
        unique: true,
        name: "idx_hda_deliveries_on_member_and_delivery"
    end
  end
end
