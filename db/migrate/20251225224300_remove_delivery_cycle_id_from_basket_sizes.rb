# frozen_string_literal: true

class RemoveDeliveryCycleIdFromBasketSizes < ActiveRecord::Migration[8.1]
  def change
    remove_reference :basket_sizes, :delivery_cycle, foreign_key: true
  end
end
