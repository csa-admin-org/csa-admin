# frozen_string_literal: true

require "test_helper"

class PromotionClaimTest < ActiveSupport::TestCase
  setup { travel_to "2026-06-01" }

  test "one live claim per member, and a voided claim can be replaced" do
    member = create_member
    first_offer = code
    first = PromotionClaim.claim!(member, first_offer)
    replacement = PromotionClaim.claim!(member, code)

    assert first.reload.voided?
    assert_not_equal first_offer, replacement.promotion
    assert_equal 1, PromotionClaim.live_for(member).count
  end

  test "an expired unused claim can be replaced" do
    member = create_member
    expired = PromotionClaim.claim!(member, code)
    expired.update_column(:expires_on, Date.current - 1.day)

    replacement = PromotionClaim.claim!(member, code)

    assert_not expired.reload.voided?
    assert replacement.persisted?
  end

  test "a failed claim leaves the live row" do
    member = create_member
    live = PromotionClaim.claim!(member, code)
    ended = code(name: "Ended")
    ended.update_columns(state: "archived")

    assert_raises(PromotionClaim::NotRedeemable) do
      PromotionClaim.claim!(member, ended)
    end
    assert_not live.reload.voided?
    assert_equal 1, PromotionClaim.live_for(member).count
  end

  test "a claim on a membership that is no longer trial-only is applied" do
    membership = memberships(:jane)
    membership.update_columns(baskets_count: 10, trial_baskets_count: 0)
    redemption = PromotionClaim.claim!(membership.member, code, membership: membership)
    helper = Object.new.extend(MembersHelper)

    assert redemption.on_committed_membership?
    assert_equal "applied", helper.promotion_claim_state(redemption)

    membership.update_columns(baskets_count: 4, trial_baskets_count: 4)
    redemption.reload

    assert_not redemption.on_committed_membership?
    assert_equal "pending", helper.promotion_claim_state(redemption)
  end

  test "voiding and reapplying the same promotion on the same membership reuses the row" do
    membership = memberships(:jane)
    offer = code
    redemption = PromotionClaim.claim!(membership.member, offer, membership: membership)
    redemption.update_column(:benefit_amount, 10)
    redemption.void!

    reused = PromotionClaim.claim!(membership.member, offer, membership: membership)

    assert_equal redemption.id, reused.id
    assert_not reused.voided?
    assert_nil reused.benefit_amount
    assert_equal 1, membership.member.promotion_claims.where(promotion: offer, membership: membership).count
  end

  test "voiding a billed claim lets an admin attach another" do
    member = create_member
    membership = memberships(:jane)
    billed = PromotionClaim.claim!(member, code, membership: membership)
    other = code(name: "Winter")

    billed.void!
    replacement = PromotionClaim.claim!(member, other, membership: membership)

    assert billed.reload.voided?
    assert_equal replacement, membership.reload.promotion_claim
  end

  test "void frees a single-use slot and stops billing" do
    campaign = code(max_uses: 1)
    member = create_member
    redemption = PromotionClaim.claim!(member, campaign, membership: memberships(:jane))
    redemption.recompute_benefit_amount!

    assert_not campaign.reload.redeemable?

    redemption.void!

    assert campaign.reload.redeemable?
    assert_not redemption.billable?
    assert_equal 0, campaign.occupying_count
  end

  test "a salary basket membership is not a claim target" do
    member = members(:john)
    member.update_column(:salary_basket, true)
    membership = memberships(:john)

    assert_not Promotion.acceptable_target?(member, membership)
  end

  test "a commitment claim is billed on a trial-only membership, and stays billed after it" do
    membership = memberships(:john)
    membership.update_columns(baskets_count: 2, trial_baskets_count: 2)
    redemption = PromotionClaim.claim!(
      membership.member,
      code(commitment_required: true),
      membership: membership)
    redemption.recompute_benefit_amount!

    assert membership.trial_only?
    assert redemption.benefit_amount.positive?
    assert redemption.billable?

    membership.update_columns(baskets_count: 10, trial_baskets_count: 2)
    redemption.recompute_benefit_amount!

    assert redemption.reload.benefit_amount.positive?
    assert redemption.billable?
  end

  test "an archived offer still bills an existing claim" do
    membership = memberships(:john)
    campaign = code
    redemption = PromotionClaim.claim!(membership.member, campaign, membership: membership)
    redemption.recompute_benefit_amount!
    campaign.update!(state: "archived")

    assert redemption.reload.billable?
    assert_equal "Campaign", redemption.public_name
    assert_nil Promotion.find_redeemable(campaign.code)
  end

  test "editing the offer does not rewrite an existing claim" do
    membership = memberships(:john)
    campaign = code
    redemption = PromotionClaim.claim!(membership.member, campaign, membership: membership)

    campaign.update!(name: "Winter", amount: 1)

    assert_equal "Campaign", redemption.reload.public_name
    assert_equal 15, redemption.amount
    assert_equal "Winter", campaign.name
  end

  test "a past end date does not redeem" do
    campaign = travel_to(Date.current - 2.days) { code(ends_on: Date.current + 1.day) }

    assert_nil Promotion.find_redeemable(campaign.code)
    assert_raises(PromotionClaim::NotRedeemable) do
      PromotionClaim.claim!(create_member, campaign)
    end
  end

  test "a claim past expires_on is not billed and no longer counts toward max_uses" do
    campaign = code(max_uses: 1)
    membership = memberships(:jane)
    redemption = PromotionClaim.claim!(membership.member, campaign, membership: membership)
    redemption.update!(expires_on: Date.current - 1.day, benefit_amount: 20)
    membership.send(:update_price_and_invoices_amount!)

    assert_not redemption.reload.billable?
    assert_nil redemption.benefit_amount
    assert_not redemption.voided?
    assert_equal membership.price_before_reduction, membership.reload.price
    assert campaign.reload.redeemable?
  end

  test "canceling a membership with nothing applied clears the membership" do
    membership = memberships(:jane)
    redemption = PromotionClaim.claim!(membership.member, code, membership: membership)
    redemption.update_column(:benefit_amount, 20)

    redemption.release!(membership)

    assert_nil redemption.reload.membership_id
    assert_nil redemption.benefit_amount
    assert_not redemption.voided?
  end

  private

  def code(**attrs)
    Promotion.create!({
      name: "Campaign",
      amount: 15
    }.merge(attrs))
  end
end
