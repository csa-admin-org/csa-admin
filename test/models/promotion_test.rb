# frozen_string_literal: true

require "test_helper"

class PromotionTest < ActiveSupport::TestCase
  setup { travel_to "2026-06-01" }

  test "generates a 12-hex token and does not regenerate it" do
    code = Promotion.create!(name: "Summer", amount: 20)
    token = code.code

    assert_match(/\A[0-9a-f]{12}\z/, token)

    code.update!(name: "Winter", amount: 5)

    assert_equal token, code.reload.code
  end

  test "finds a redeemable offer until the day after ends_on" do
    code = promotion(ends_on: "2026-07-01")

    assert_equal code, Promotion.find_redeemable(code.code)
    assert_equal code, Promotion.find_redeemable(code.code.upcase, on: Date.new(2026, 7, 1))
    assert_nil Promotion.find_redeemable(code.code, on: Date.new(2026, 7, 2))
  end

  test "an archived or discarded promotion is not redeemable" do
    archived = promotion
    archived.archive!
    discarded = promotion
    discarded.discard!

    assert_nil archived.ends_on
    assert_nil Promotion.find_redeemable(archived.code)
    assert_nil Promotion.find_redeemable(discarded.code)
    assert_not archived.redeemable?
    assert_not archived.can_update?
  end

  test "a past end date is refused" do
    code = promotion

    assert_not code.update(ends_on: "2026-05-01")
    assert code.errors[:ends_on].any?
    assert_equal "active", code.reload.state
  end

  test "a blank end date stays open" do
    code = promotion

    assert code.redeemable?
    assert_equal "active", code.state
  end

  test "archive_ended archives yesterday and clears the date" do
    due = travel_to("2026-05-31") { promotion(ends_on: "2026-05-31") }
    today = promotion(ends_on: "2026-06-01")

    Promotion.archive_ended!

    assert_equal "archived", due.reload.state
    assert_nil due.ends_on
    assert_equal "active", today.reload.state
    assert_equal Date.new(2026, 6, 1), today.ends_on
  end

  test "unique mode stores one use and unlimited clears it" do
    code = promotion(max_uses_mode: "unique")

    assert_equal 1, code.max_uses
    assert_equal "unique", code.max_uses_mode

    code.update!(max_uses_mode: "unlimited")

    assert_nil code.reload.max_uses
    assert_equal "unlimited", code.max_uses_mode
  end

  test "delete removes an unused promotion and refuses one with a claim" do
    unused = promotion
    used = promotion
    PromotionClaim.claim!(create_member, used)

    assert unused.can_destroy?
    assert_difference -> { Promotion.count }, -1 do
      unused.destroy
    end

    assert_not used.can_destroy?
    assert_raises(RuntimeError) { used.destroy }
    assert used.reload.kept?
  end

  test "a single-use offer is not redeemable once its slot is occupied" do
    code = promotion(max_uses: 1)
    member = create_member
    PromotionClaim.claim!(member, code)

    assert_not code.reload.redeemable?
    assert_equal 1, code.occupying_count
  end

  test "fixed benefit is capped at the membership price" do
    code = promotion(amount: 500)
    membership = memberships(:john)
    redemption = claim_for(membership, code)

    assert_equal membership.price, redemption.benefit_amount
  end

  test "a fixed amount is of the membership price after a price reduction" do
    org(features: Current.org.features | [ "price_reductions" ])
    membership = memberships(:jane)
    reduction = PriceReduction.create!(names: { "en" => "Caritas" }, percentage: 50)
    membership.apply_price_reduction!(reduction)
    membership.save!
    gross = membership.reload.price

    redemption = claim_for(membership, promotion(amount: 10))
    membership.send(:update_price_and_invoices_amount!)

    assert_equal 10, redemption.benefit_amount
    assert_equal gross - 10, membership.reload.price
  end

  test "a zero amount is refused" do
    zero = Promotion.new(name: "Campaign", amount: 0)

    assert_not zero.valid?
  end

  test "a used unique promotion is not offered, except the one already on the membership" do
    used = promotion(max_uses: 1)
    open = promotion(max_uses: 1)
    poster = promotion
    PromotionClaim.claim!(members(:jane), used)

    helper = Object.new.extend(MembersHelper)
    options = helper.promotion_options(used)

    assert_includes options.map(&:last), used.id
    assert_includes options.map(&:last), open.id
    assert_includes options.map(&:last), poster.id
    assert_equal "Campaign (-15\u00A0CHF)", options.find { |_, id| id == open.id }.first
    assert_not_includes helper.promotion_options.map(&:last), used.id
  end

  private

  def promotion(**attrs)
    Promotion.create!({
      name: "Campaign",
      amount: 15
    }.merge(attrs))
  end

  def claim_for(membership, code)
    redemption = PromotionClaim.claim!(membership.member, code, membership: membership)
    redemption.recompute_benefit_amount!
    redemption.reload
  end
end
