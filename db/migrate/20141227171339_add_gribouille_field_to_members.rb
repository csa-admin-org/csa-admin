class AddGribouilleFieldToMembers < ActiveRecord::Migration[4.2]
  def change
    add_column :members, :gribouille, :boolean, default: false, null: false
  end
end
