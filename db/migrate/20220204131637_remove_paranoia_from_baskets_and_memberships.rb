class RemoveParanoiaFromBasketsAndMemberships < ActiveRecord::Migration[6.1]
  def change
    execute 'DELETE FROM baskets WHERE deleted_at IS NOT NULL'
    remove_column :baskets, :deleted_at

    execute 'DELETE FROM memberships WHERE deleted_at IS NOT NULL'
    remove_column :memberships, :deleted_at
  end
end
