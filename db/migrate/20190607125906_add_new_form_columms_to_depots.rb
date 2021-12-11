class AddNewFormColummsToDepots < ActiveRecord::Migration[5.2]
  def change
    add_column :depots, :public_names, :jsonb, default: {}, null: false
    add_column :depots, :form_priority, :integer, default: 0, null: false
  end
end
