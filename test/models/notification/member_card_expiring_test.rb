# frozen_string_literal: true

require "test_helper"

class Notification::MemberCardExpiringTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
    admins(:ultra).update!(notifications: [ "member_card_expiring" ])
    MailTemplate.find_or_create_by!(title: "price_reduction_card_expiring")
  end

  test "notifies the member and one admin digest for a card tied to a current grant" do
    card = expiring_card(members(:jane))
    reduction = PriceReduction.create!(
      names: { "en" => "Caritas" },
      percentage: 10,
      price_reduction_card: card.price_reduction_card)
    MembershipPriceReduction.create!(
      membership: memberships(:jane),
      price_reduction: reduction,
      percentage: 10,
      amount: 5)

    assert_difference -> { ActionMailer::Base.deliveries.size }, 2 do
      Notification::MemberCardExpiring.notify
      perform_enqueued_jobs
    end

    assert_equal card.expires_on, card.reload.expiration_notice_sent_on
    assert_includes ActionMailer::Base.deliveries.map { |mail| mail.to }.flatten, admins(:ultra).email
    member_mail = ActionMailer::Base.deliveries.find { |mail| mail.to.include?(members(:jane).emails_array.first) }
    assert_includes member_mail.body.encoded, "5678"
    assert_not_includes member_mail.body.encoded, "CC-12345678"
  end

  test "uses the delay on the expiry mail template" do
    expiring_card(members(:mary))
    template = MailTemplate.find_by!(title: "price_reduction_card_expiring")
    template.update!(delay_in_days: 0)
    assert_equal 0, template.reload.delay_in_days

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      Notification::MemberCardExpiring.notify
      perform_enqueued_jobs
    end
  end

  test "skips the admin digest when the card is not tied to a current grant or a waiting selection" do
    card = expiring_card(members(:mary))

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::MemberCardExpiring.notify
      perform_enqueued_jobs
    end

    assert_equal card.expires_on, card.reload.expiration_notice_sent_on
    assert_not_includes ActionMailer::Base.deliveries.map { |mail| mail.to }.flatten, admins(:ultra).email
  end

  private

  def expiring_card(member)
    type = PriceReductionCard.create!(
      names: { "en" => "CarteCulture" },
      require_name: true,
      require_number: true,
      require_expires_on: true)
    member.member_cards.create!(
      price_reduction_card: type,
      name: member.name,
      number: "CC-12345678",
      expires_on: Date.new(2024, 6, 15))
  end
end
