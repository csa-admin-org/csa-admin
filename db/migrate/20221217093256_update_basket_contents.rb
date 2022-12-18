class UpdateBasketContents < ActiveRecord::Migration[7.0]
  def change
    remove_column :basket_contents, :same_basket_quantities, :boolean, null: false, default: false
    add_column :basket_contents, :distribution_mode, :string, null: false, default: 'automatic'
  end
end
