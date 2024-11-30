# frozen_string_literal: true

class AddPriceToDeliveryCycles < ActiveRecord::Migration[8.0]
  def change
    add_column :delivery_cycles, :price, :decimal, precision: 8, scale: 2, null: false, default: "0.0"
    add_column :memberships, :delivery_cycle_price, :decimal, precision: 8, scale: 2
    add_column :baskets, :delivery_cycle_price, :decimal, precision: 8, scale: 2

    up_only do
      execute "UPDATE memberships SET delivery_cycle_price = 0.0"
      execute "UPDATE baskets SET delivery_cycle_price = 0.0"
    end

    change_column_null :memberships, :delivery_cycle_price, false
    change_column_null :baskets, :delivery_cycle_price, false
  end
end
