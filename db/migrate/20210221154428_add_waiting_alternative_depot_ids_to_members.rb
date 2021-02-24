class AddWaitingAlternativeDepotIdsToMembers < ActiveRecord::Migration[6.1]
  def change
    create_join_table :depots, :members, table_name: 'members_waiting_alternative_depots'
  end
end
