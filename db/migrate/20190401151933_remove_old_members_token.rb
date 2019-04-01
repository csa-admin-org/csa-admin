class RemoveOldMembersToken < ActiveRecord::Migration[5.2]
  def change
    remove_column :members, :token
  end
end
