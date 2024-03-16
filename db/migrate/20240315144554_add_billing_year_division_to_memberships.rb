class AddBillingYearDivisionToMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :memberships, :billing_year_division, :integer, null: false, default: 1
    add_column :members, :waiting_billing_year_division, :integer

    up_only do
      if Tenant.inside?
        Member.where.not(waiting_basket_size_id: nil).find_each do |m|
          m.update_column(:waiting_billing_year_division, m.billing_year_division)
        end
        Membership.includes(:member).find_each do |m|
          m.update_column(:billing_year_division, m.member.billing_year_division)
        end
      end
    end
  end
end
