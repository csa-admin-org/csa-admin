class AddRenewBooleanToMember < ActiveRecord::Migration[4.2]
  def change
    add_column :members, :renew_membership, :boolean, default: false, null: false
  end
end
