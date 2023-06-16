class AddMemberIdsPositionToDepots < ActiveRecord::Migration[7.0]
  def change
    add_column :depots, :member_ids_position, :integer, array: true, default: []
  end
end
