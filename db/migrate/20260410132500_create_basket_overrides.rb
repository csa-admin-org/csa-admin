# frozen_string_literal: true

class CreateBasketOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :basket_overrides do |t|
      t.references :membership, null: false, index: true
      t.references :delivery, null: false, index: true
      t.references :session, index: true
      t.json :diff, null: false, default: {}
      t.timestamps

      t.index [ :membership_id, :delivery_id ], unique: true
    end
  end
end
