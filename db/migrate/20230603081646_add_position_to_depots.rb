# frozen_string_literal: true

class AddPositionToDepots < ActiveRecord::Migration[7.0]
  def change
    add_column :depots, :position, :integer
    Depot.reorder_by_name.each.with_index(1) do |depot, index|
      depot.update_column :position, index
    end
  end
end
