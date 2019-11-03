class CreateGroupBuyingDeliveries < ActiveRecord::Migration[6.0]
  def change
    create_table :group_buying_deliveries do |t|
      t.date :date, null: false
      t.date :orderable_until, null: false
    end
  end
end
