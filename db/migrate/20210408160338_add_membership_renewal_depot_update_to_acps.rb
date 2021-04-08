class AddMembershipRenewalDepotUpdateToAcps < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :membership_renewal_depot_update, :boolean, default: true, null: false
  end
end
