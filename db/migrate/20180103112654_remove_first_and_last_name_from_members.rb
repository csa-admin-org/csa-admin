class RemoveFirstAndLastNameFromMembers < ActiveRecord::Migration[5.1]
  def change
    change_column_null :members, :name, false

    remove_column :members, :first_name
    remove_column :members, :last_name
  end
end
