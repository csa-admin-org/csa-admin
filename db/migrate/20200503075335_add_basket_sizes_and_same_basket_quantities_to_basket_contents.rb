class AddBasketSizesAndSameBasketQuantitiesToBasketContents < ActiveRecord::Migration[6.0]
  def change
    add_column :basket_contents, :basket_sizes, :string, array: true, default: ['small', 'big']
    add_column :basket_contents, :same_basket_quantities, :boolean, null: false, default: false
  end
end
