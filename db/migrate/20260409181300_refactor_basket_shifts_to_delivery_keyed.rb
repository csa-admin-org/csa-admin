# frozen_string_literal: true

class RefactorBasketShiftsToDeliveryKeyed < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Add new columns (nullable initially)
    add_reference :basket_shifts, :membership, null: true, foreign_key: true, index: true
    add_reference :basket_shifts, :source_delivery, null: true, foreign_key: { to_table: :deliveries }, index: true
    add_reference :basket_shifts, :target_delivery, null: true, foreign_key: { to_table: :deliveries }, index: true

    # Step 2: Backfill data from existing basket associations
    execute <<~SQL
      UPDATE basket_shifts
      SET membership_id = (SELECT membership_id FROM baskets WHERE baskets.id = basket_shifts.source_basket_id),
          source_delivery_id = (SELECT delivery_id FROM baskets WHERE baskets.id = basket_shifts.source_basket_id),
          target_delivery_id = (SELECT delivery_id FROM baskets WHERE baskets.id = basket_shifts.target_basket_id)
    SQL

    # Step 3: Add NOT NULL constraints after backfill
    change_column_null :basket_shifts, :membership_id, false
    change_column_null :basket_shifts, :source_delivery_id, false
    change_column_null :basket_shifts, :target_delivery_id, false

    # Step 4: Add new unique index, remove old one
    add_index :basket_shifts, [ :membership_id, :source_delivery_id ], unique: true
    remove_index :basket_shifts, [ :absence_id, :source_basket_id ]

    # Step 5: Remove old FK columns
    remove_reference :basket_shifts, :source_basket, foreign_key: { to_table: :baskets }, index: true
    remove_reference :basket_shifts, :target_basket, foreign_key: { to_table: :baskets }, index: true
  end

  def down
    # Step 1: Re-add old FK columns
    add_reference :basket_shifts, :source_basket, null: true, foreign_key: { to_table: :baskets }, index: true
    add_reference :basket_shifts, :target_basket, null: true, foreign_key: { to_table: :baskets }, index: true

    # Step 2: Backfill from delivery associations
    execute <<~SQL
      UPDATE basket_shifts
      SET source_basket_id = (
            SELECT baskets.id FROM baskets
            WHERE baskets.membership_id = basket_shifts.membership_id
              AND baskets.delivery_id = basket_shifts.source_delivery_id
            LIMIT 1
          ),
          target_basket_id = (
            SELECT baskets.id FROM baskets
            WHERE baskets.membership_id = basket_shifts.membership_id
              AND baskets.delivery_id = basket_shifts.target_delivery_id
            LIMIT 1
          )
    SQL

    # Step 3: Add NOT NULL constraints
    change_column_null :basket_shifts, :source_basket_id, false
    change_column_null :basket_shifts, :target_basket_id, false

    # Step 4: Restore old unique index, remove new one
    add_index :basket_shifts, [ :absence_id, :source_basket_id ], unique: true
    remove_index :basket_shifts, [ :membership_id, :source_delivery_id ]

    # Step 5: Remove delivery-keyed columns
    remove_reference :basket_shifts, :membership, foreign_key: true, index: true
    remove_reference :basket_shifts, :source_delivery, foreign_key: { to_table: :deliveries }, index: true
    remove_reference :basket_shifts, :target_delivery, foreign_key: { to_table: :deliveries }, index: true
  end
end
