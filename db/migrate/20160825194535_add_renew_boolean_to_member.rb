class AddRenewBooleanToMember < ActiveRecord::Migration
  def change
    add_column :members, :renew_membership, :boolean, default: false, null: false
  end
end
