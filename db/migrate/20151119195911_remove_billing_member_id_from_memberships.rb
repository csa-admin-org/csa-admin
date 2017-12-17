class RemoveBillingMemberIdFromMemberships < ActiveRecord::Migration[4.2]
  def up
    remove_column :memberships, :billing_member_id
  end
end
