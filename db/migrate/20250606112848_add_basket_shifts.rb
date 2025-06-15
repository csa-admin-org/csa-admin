# frozen_string_literal: true

class AddBasketShifts < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :basket_shifts_annually, :integer, default: 0
    add_column :organizations, :basket_shift_deadline_in_weeks, :integer, default: 4

    add_column :baskets, :shift_declined_at, :datetime

    create_table :basket_shifts do |t|
      t.references :absence, null: false, foreign_key: true, index: true
      t.references :source_basket, null: false, foreign_key: { to_table: :baskets }, index: true
      t.references :target_basket, null: false, foreign_key: { to_table: :baskets }, index: true
      t.json :quantities, default: {}, null: false
      t.timestamps
    end

    add_index :basket_shifts, [ :absence_id, :source_basket_id ], unique: true
  end
end
