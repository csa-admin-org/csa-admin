# frozen_string_literal: true

class RemoveYearFromBaskets < ActiveRecord::Migration[5.1]
  def change
    remove_column :baskets, :year
  end
end
