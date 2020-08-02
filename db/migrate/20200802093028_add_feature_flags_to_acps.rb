class AddFeatureFlagsToAcps < ActiveRecord::Migration[6.0]
  def change
    add_column :acps, :feature_flags, :string, array: true, default: [], null: false
  end
end
