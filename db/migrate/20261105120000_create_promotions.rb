# frozen_string_literal: true

class CreatePromotions < ActiveRecord::Migration[8.1]
  def change
    create_table :promotions do |t|
      t.string :code, null: false
      t.json :names, null: false, default: {}
      t.json :public_names, null: false, default: {}
      t.string :state, null: false, default: "active"
      t.date :ends_on
      t.integer :max_uses
      t.decimal :amount, precision: 8, scale: 2, null: false
      t.boolean :commitment_required, null: false, default: false
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :promotions, :code, unique: true
    add_index :promotions, :discarded_at

    add_check_constraint :promotions,
      "state IN ('active', 'archived')",
      name: "promotions_state"
    add_check_constraint :promotions,
      "max_uses IS NULL OR max_uses = 1",
      name: "promotions_max_uses"

    create_table :promotion_claims do |t|
      t.references :promotion, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.references :membership, foreign_key: true
      t.decimal :amount, precision: 8, scale: 2, null: false
      t.boolean :commitment_required, null: false, default: false
      t.decimal :benefit_amount, precision: 8, scale: 2
      t.datetime :voided_at
      t.date :expires_on, null: false
      t.json :names, null: false, default: {}
      t.json :public_names, null: false, default: {}
      t.timestamps
    end

    add_index :promotion_claims, [ :promotion_id, :member_id, :membership_id ],
      unique: true,
      name: "index_promotion_claims_on_promotion_member_membership"
    add_index :promotion_claims, :expires_on
    add_index :promotion_claims, :voided_at

    add_reference :members, :waiting_promotion,
      foreign_key: { to_table: :promotions },
      null: true
  end
end
