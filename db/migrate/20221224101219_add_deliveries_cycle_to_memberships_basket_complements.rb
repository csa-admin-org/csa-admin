class AddDeliveriesCycleToMembershipsBasketComplements < ActiveRecord::Migration[7.0]
  def change
    add_reference :memberships_basket_complements, :deliveries_cycle, foreign_key: true, index: false
  end
end
