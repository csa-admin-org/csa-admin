class RenameDepotFormNamesToPublicNames < ActiveRecord::Migration[6.1]
  def change
    rename_column :depots, :form_names, :public_names
  end
end
