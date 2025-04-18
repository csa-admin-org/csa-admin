# frozen_string_literal: true

class AddNamesToDepots < ActiveRecord::Migration[8.1]
  def change
    add_column :depots, :names, :json, default: {}, null: false
  end
end
