# frozen_string_literal: true

class AddCweekColumnsToBasketSizes < ActiveRecord::Migration[8.0]
  def change
    add_column :basket_sizes, :first_cweek, :integer
    add_column :basket_sizes, :last_cweek, :integer
  end
end
