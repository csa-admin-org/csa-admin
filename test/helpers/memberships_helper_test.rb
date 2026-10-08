# frozen_string_literal: true

require "test_helper"

class MembershipsHelperTest < ActionView::TestCase
  test "memberships_for_sidebar keeps association joins and distinct ids" do
    members(:jane).update!(city: "Lausanne")
    MembershipsBasketComplement.create!(
      membership: memberships(:jane),
      basket_complement: basket_complements(:eggs),
      quantity: 1,
      price: 6)

    relation = Membership
      .includes(:member, :price_reduction)
      .left_joins(:memberships_basket_complements)
      .where(members: { city: "Lausanne" })
      .joins(:member)
      .merge(Member.order_by_name)
      .limit(1)
      .distinct

    all = memberships_for_sidebar(relation)

    assert_equal [ memberships(:jane).id ], all.ids
    assert_equal memberships(:jane).price, all.sum(:price)
  end
end
