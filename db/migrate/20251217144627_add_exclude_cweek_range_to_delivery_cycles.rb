# frozen_string_literal: true

class AddExcludeCweekRangeToDeliveryCycles < ActiveRecord::Migration[8.1]
  def change
    add_column :delivery_cycles, :exclude_cweek_range, :boolean, default: false, null: false
  end
end
