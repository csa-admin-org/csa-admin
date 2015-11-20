class RemoveBillingMemberIdFromMemberships < ActiveRecord::Migration
  def up
    remove_column :memberships, :billing_member_id
  end
end
