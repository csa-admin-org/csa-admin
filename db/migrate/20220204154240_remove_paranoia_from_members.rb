class RemoveParanoiaFromMembers < ActiveRecord::Migration[6.1]
  def change
    execute 'DELETE FROM members WHERE deleted_at IS NOT NULL'
    remove_column :members, :deleted_at
  end
end
