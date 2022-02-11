class DropDeliveriesDepotsTableAndSeasonsColumns < ActiveRecord::Migration[6.1]
  def change
    drop_table :deliveries_depots
    remove_column :memberships, :seasons
    remove_column :memberships_basket_complements, :seasons
    remove_column :acps, :summer_month_range
  end
end
