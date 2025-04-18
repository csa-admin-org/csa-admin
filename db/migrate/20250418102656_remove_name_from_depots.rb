# frozen_string_literal: true

class RemoveNameFromDepots < ActiveRecord::Migration[8.1]
  def change
    remove_column :depots, :name, :string
  end
end
