# frozen_string_literal: true

class AddBiddingRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :bidding_rounds do |t|
      t.integer :fy_year, null: false
      t.integer :number, null: false
      t.string :state, null: false, default: "draft"
      t.timestamps
    end
    add_index :bidding_rounds, :fy_year
    add_index :bidding_rounds, [ :fy_year, :number ], unique: true
    add_index :bidding_rounds, :state, unique: true, where: "state = 'draft'", name: "index_bidding_rounds_on_state_draft"
    add_index :bidding_rounds, :state, unique: true, where: "state = 'open'", name: "index_bidding_rounds_on_state_open"

    create_table :bidding_round_pledges do |t|
      t.references :bidding_round, null: false, foreign_key: true, index: true
      t.references :membership, null: false, foreign_key: true, index: true
      t.decimal :basket_size_price, precision: 8, scale: 2, null: false
      t.timestamps
    end
    add_index :bidding_round_pledges, [ :bidding_round_id, :membership_id ], unique: true

    add_column :organizations, :bidding_round_basket_size_price_min_percentage, :integer, default: 0
    add_column :organizations, :bidding_round_basket_size_price_max_percentage, :integer, default: 100
    add_column :organizations, :open_bidding_round_reminder_sent_after_in_days, :integer
  end
end
