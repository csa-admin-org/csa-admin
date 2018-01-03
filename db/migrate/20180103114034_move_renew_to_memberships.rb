class MoveRenewToMemberships < ActiveRecord::Migration[5.1]
  def change
    remove_column :members, :renew_membership
    add_column :memberships, :renew, :boolean, default: false, null: false
  end
end
