# frozen_string_literal: true

class AddCompletionDataToBiddingRounds < ActiveRecord::Migration[8.1]
  def change
    add_column :bidding_rounds, :eligible_memberships_count, :integer
    add_column :bidding_rounds, :total_expected_value, :decimal, precision: 8, scale: 2
    add_column :bidding_rounds, :total_final_value, :decimal, precision: 8, scale: 2
  end
end
