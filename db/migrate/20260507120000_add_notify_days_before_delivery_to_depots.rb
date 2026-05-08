# frozen_string_literal: true

class AddNotifyDaysBeforeDeliveryToDepots < ActiveRecord::Migration[8.1]
  def change
    add_column :depots, :notify_days_before_delivery, :integer, default: 1, null: false
  end
end
