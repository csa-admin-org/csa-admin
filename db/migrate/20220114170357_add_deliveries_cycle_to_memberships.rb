class AddDeliveriesCycleToMemberships < ActiveRecord::Migration[6.1]
  def change
    add_reference :memberships, :deliveries_cycle, foreign_key: true, index: true

    Membership.with_deleted.includes(:depot).find_each do |m|
      m.update_column :deliveries_cycle_id, m.depot.deliveries_cycle_ids.first
    end

    change_column_null :memberships, :deliveries_cycle_id, false
  end
end
