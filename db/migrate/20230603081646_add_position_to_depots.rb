class AddPositionToDepots < ActiveRecord::Migration[7.0]
  def change
    add_column :depots, :position, :integer
    Depot.reorder(:name).each.with_index(1) do |depot, index|
      depot.update_column :position, index
    end
  end
end
