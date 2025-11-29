# frozen_string_literal: true

class AddWeekNumbersRangeToDeliveryCycles < ActiveRecord::Migration[8.1]
  def change
    add_column :delivery_cycles, :first_cweek, :integer
    add_column :delivery_cycles, :last_cweek, :integer
  end
end
