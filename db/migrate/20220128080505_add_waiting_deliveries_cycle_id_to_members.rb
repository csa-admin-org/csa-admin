# frozen_string_literal: true

class AddWaitingDeliveriesCycleIdToMembers < ActiveRecord::Migration[6.1]
  def change
    add_column :members, :waiting_deliveries_cycle_id, :bigint
  end
end
