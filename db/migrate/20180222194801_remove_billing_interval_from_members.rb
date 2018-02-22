class RemoveBillingIntervalFromMembers < ActiveRecord::Migration[5.2]
  def change
    remove_column :members, :billing_interval
  end
end
