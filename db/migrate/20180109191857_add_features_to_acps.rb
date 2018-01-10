class AddFeaturesToAcps < ActiveRecord::Migration[5.2]
  def change
    add_column :acps, :features, :string, array: true, default: [], null: false
  end
end
