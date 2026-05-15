# frozen_string_literal: true

class AddShopDeliveryCycleIdToMembers < ActiveRecord::Migration[8.0]
  def change
    add_reference :members, :shop_delivery_cycle, foreign_key: { to_table: :delivery_cycles }
  end
end
