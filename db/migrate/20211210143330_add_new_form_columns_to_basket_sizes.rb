class AddNewFormColumnsToBasketSizes < ActiveRecord::Migration[6.1]
  def change
    add_column :basket_sizes, :public_names, :jsonb, default: {}, null: false
    add_column :basket_sizes, :form_priority, :integer, default: 0, null: false
  end
end
