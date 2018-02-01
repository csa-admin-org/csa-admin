class AddColumnsToMembers < ActiveRecord::Migration[5.2]
  def change
    add_column :members, :profession, :string
    add_column :members, :come_from, :string
  end
end
