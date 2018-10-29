class RenameDistributionsToDepots < ActiveRecord::Migration[5.2]
  def change
    rename_table :distributions, :depots
    rename_table :basket_contents_distributions, :basket_contents_depots

    rename_index :basket_contents_depots, :index_basket_contents_distributions_unique, :index_basket_contents_depots_unique

    rename_column :baskets, :distribution_id, :depot_id
    rename_column :baskets, :distribution_price, :depot_price
    rename_column :basket_contents_depots, :distribution_id, :depot_id
    rename_column :memberships, :distribution_id, :depot_id
    rename_column :memberships, :distribution_price, :depot_price
    rename_column :members, :waiting_distribution_id, :waiting_depot_id

    add_foreign_key :memberships, :depots
    add_foreign_key :members, :depots, column: :waiting_depot_id
  end
end
