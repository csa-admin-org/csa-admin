class UpdateMembershipsBilling < ActiveRecord::Migration
  def change
    remove_column :memberships, :distribution_basket_price
    remove_column :baskets, :annual_halfday_works
    Membership
      .where(annual_halfday_works: nil)
      .update_all(annual_halfday_works: HalfdayWork::MEMBER_PER_YEAR)
    rename_column :memberships, :annual_price, :halfday_works_annual_price
  end
end
