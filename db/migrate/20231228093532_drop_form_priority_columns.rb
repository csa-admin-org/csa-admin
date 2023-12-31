class DropFormPriorityColumns < ActiveRecord::Migration[7.1]
  def change
    remove_column :basket_sizes, :form_priority, :integer, default: 1, null: false
    remove_column :basket_complements, :form_priority, :integer, default: 1, null: false
    remove_column :depots, :form_priority, :integer, default: 1, null: false
    remove_column :delivery_cycles, :form_priority, :integer, default: 1, null: false
  end
end
