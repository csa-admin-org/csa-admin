# frozen_string_literal: true

class AddFormDetailsToDeliveryCycles < ActiveRecord::Migration[7.2]
  def change
    add_column :delivery_cycles, :form_details, :jsonb, default: {}, null: false
  end
end
