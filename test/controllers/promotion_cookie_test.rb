# frozen_string_literal: true

require "test_helper"

class PromotionCookieTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    @code = Promotion.create!(name: "Summer", code: "SUMMER", amount: 20)
  end

  test "a redeemable ref sets an unsigned parent-domain cookie for 90 days" do
    travel_to Time.zone.local(2026, 6, 1, 12) do
      get new_members_member_path, params: { ref: "summer" }

      assert_response :success
      assert_select ".promotion-banner-title", text: "Summer"
      assert_select ".promotion-banner-amount", text: "-20 CHF"
      jar = cookies.get_cookie("ref")
      header = response.headers["Set-Cookie"]
      assert_equal "summer", jar.value
      assert_equal "acme.test", jar.domain
      assert_match(/domain=\.acme\.test/i, header)
      assert_equal "/", jar.path
      assert_match(/samesite=lax/i, header)
      assert_no_match(/httponly|secure/i, header)
      assert_in_delta 90.days.from_now.to_i, jar.expires.to_time.to_i, 5
    end
  end

  test "the banner shows the end date and the commitment" do
    @code.update!(ends_on: Date.new(2026, 12, 31), commitment_required: true)

    get new_members_member_path, params: { ref: "SUMMER" }

    assert_select ".promotion-banner-note", text: "Expires #{I18n.l(Date.new(2026, 12, 31), format: :short)}. Commitment beyond the trial required."
  end

  test "a code that is no longer valid shows the banner once and clears the cookie" do
    @code.archive!

    get new_members_member_path, params: { ref: "SUMMER" }

    assert_select ".promotion-banner.is-invalid", text: "Summer is no longer valid."
    assert_nil cookies[:ref]

    get new_members_member_path

    assert_select ".promotion-banner", count: 0
  end

  test "a used unique code shows the same banner" do
    @code.update!(max_uses: 1)
    PromotionClaim.claim!(members(:jane), @code)

    get new_members_member_path, params: { ref: "SUMMER" }

    assert_select ".promotion-banner.is-invalid", text: "Summer is no longer valid."
    assert_nil cookies[:ref]
  end

  test "an unknown code clears the cookie and shows no banner" do
    get new_members_member_path, params: { ref: "NOPE" }

    assert_response :success
    assert_select ".promotion-banner", count: 0
    assert_nil cookies[:ref]
  end

  test "a code with unexpected characters is not stored" do
    get new_members_member_path, params: { ref: "SUMMER?next" }

    assert_select ".promotion-banner", count: 0
    assert_nil cookies[:ref]
  end

  test "promo is an alias of ref" do
    get new_members_member_path, params: { promo: "SUMMER" }

    assert_select ".promotion-banner-title", text: "Summer"
    assert_equal "SUMMER", cookies[:ref]
  end

  test "the public form has no code field" do
    get new_members_member_path, params: { ref: "SUMMER" }

    assert_select "input[name='member[promotion]']", count: 0
    assert_select "input[name='member[waiting_promotion_id]']", count: 0
  end

  test "the price preview includes the promotion" do
    travel_to "2024-01-01" do
      get new_members_member_path, params: {
        ref: "SUMMER",
        member: {
          waiting_basket_size_id: basket_sizes(:small).id,
          waiting_delivery_cycle_id: delivery_cycles(:mondays).id
        }
      }

      assert_select "#pricing .pricing-amount", text: "CHF\u00A080.00 /year"
    end
  end
end
