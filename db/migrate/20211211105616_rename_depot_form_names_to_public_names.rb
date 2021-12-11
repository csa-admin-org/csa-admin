class RenameDepotFormNamesToPublicNames < ActiveRecord::Migration[6.1]
  def change
    rename_column :depots, :public_names, :public_names
  end
end
