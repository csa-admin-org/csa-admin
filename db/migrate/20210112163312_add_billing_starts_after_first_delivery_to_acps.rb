class AddBillingStartsAfterFirstDeliveryToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :billing_starts_after_first_delivery, :boolean, null: false, default: true
  end
end
