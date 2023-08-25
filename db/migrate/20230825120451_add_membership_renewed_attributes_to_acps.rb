class AddMembershipRenewedAttributesToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :membership_renewed_attributes, :string, array: true, default: MembershipRenewal::OPTIONAL_ATTRIBUTES
  end
end
