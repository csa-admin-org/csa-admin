class AddBillingEndsOnLastDeliveryFyMonthToAcps < ActiveRecord::Migration[7.1]
  def change
    add_column :acps, :billing_ends_on_last_delivery_fy_month, :boolean, null: false, default: false
  end
end
