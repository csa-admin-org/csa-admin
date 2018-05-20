class RenameGribouilleToNewsletterOnMembers < ActiveRecord::Migration[5.2]
  def change
    rename_column :members, :gribouille, :newsletter
  end
end
