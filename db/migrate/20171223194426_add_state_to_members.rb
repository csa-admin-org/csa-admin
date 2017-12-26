class AddStateToMembers < ActiveRecord::Migration[5.1]
  def change
    add_column :members, :state, :string, default: 'pending', null: false
    add_index :members, :state
  end
end
