class AddAllowAlternativeDepotsToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :allow_alternative_depots, :boolean, default: false, null: false
  end
end
