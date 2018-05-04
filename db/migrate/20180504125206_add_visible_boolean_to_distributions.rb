class AddVisibleBooleanToDistributions < ActiveRecord::Migration[5.2]
  def change
    add_column :distributions, :visible, :boolean, null: false, default: true
    add_index :distributions, :visible
  end
end
