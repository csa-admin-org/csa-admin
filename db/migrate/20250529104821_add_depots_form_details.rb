# frozen_string_literal: true

class AddDepotsFormDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :depots, :form_details, :json, default: {}, null: false
  end
end
