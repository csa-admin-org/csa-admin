class AddMembershipComplementsUpdateAllowedToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :membership_complements_update_allowed, :boolean, default: false, null: false
  end
end
