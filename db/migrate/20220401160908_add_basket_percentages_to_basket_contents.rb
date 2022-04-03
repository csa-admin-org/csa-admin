class AddBasketPercentagesToBasketContents < ActiveRecord::Migration[7.0]
  def change
    add_column :basket_contents, :basket_percentages, :integer, default: [], null: false, array: true
  end
end
