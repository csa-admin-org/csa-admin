class UpdateMembershipsBilling < ActiveRecord::Migration
  def change
    remove_column :memberships, :distribution_basket_price
    remove_column :baskets, :annual_halfday_works
    Membership
      .where(annual_halfday_works: nil)
      .update_all(annual_halfday_works: HalfdayWork::MEMBER_PER_YEAR)
    rename_column :memberships, :annual_price, :halfday_works_annual_price

    # To run once
    Membership.all.each do |m|
      halfday_works_annual_price =
        if m.annual_halfday_works == 0
          HalfdayWork::MEMBER_PER_YEAR * HalfdayWork::PRICE
        elsif m.halfday_works_annual_price && m.basket.annual_price > m.halfday_works_annual_price
          m.halfday_works_annual_price - m.basket.annual_price
        else
          nil
        end
      m.update!(halfday_works_annual_price: halfday_works_annual_price)
    end
  end
end
