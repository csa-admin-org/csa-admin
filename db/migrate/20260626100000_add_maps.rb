# frozen_string_literal: true

class AddMaps < ActiveRecord::Migration[8.1]
  def change
    add_column :depots, :maps_visible, :boolean, default: false, null: false
    add_column :depots, :latitude, :decimal, precision: 10, scale: 6
    add_column :depots, :longitude, :decimal, precision: 10, scale: 6
    add_index :depots, :maps_visible

    add_column :organizations, :maps_style, :string, default: "positron", null: false
  end
end
