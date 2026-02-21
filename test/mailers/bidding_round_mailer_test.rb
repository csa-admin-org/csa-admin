# frozen_string_literal: true

require "test_helper"

class BiddingRoundMailerTest < ActionMailer::TestCase
  test "opened_email" do
    travel_to "2024-01-01"
    template = mail_templates(:bidding_round_opened)
    membership = memberships(:john)
    bidding_round = bidding_rounds(:open_2024)

    mail = BiddingRoundMailer.with(
      template: template,
      member: membership.member,
      bidding_round: bidding_round,
    ).opened_email

    assert_equal "Bidding round #1 is open", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "bidding-round-opened", mail.tag
    assert_includes mail.body.to_s, "<p>Welcome to the bidding round!</p>"
    assert_includes mail.body.to_s, "<p>You can make your pledge for the coming year directly from your account.</p>"
    assert_includes mail.body.to_s, "https://members.acme.test/memberships"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "opened_reminder_email" do
    travel_to "2024-01-01"
    template = mail_templates(:bidding_round_opened_reminder)
    membership = memberships(:john)
    bidding_round = bidding_rounds(:open_2024)

    mail = BiddingRoundMailer.with(
      template: template,
      member: membership.member,
      bidding_round: bidding_round,
    ).opened_reminder_email

    assert_equal "Bidding round #1 is open (reminder)", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "bidding-round-opened-reminder", mail.tag
    assert_includes mail.body.to_s, "<p>Welcome to the bidding round!</p>"
    assert_includes mail.body.to_s, "<p>You haven't made a pledge yet. It only takes a minute to set yours now.</p>"
    assert_includes mail.body.to_s, "https://members.acme.test/memberships"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "completed_email" do
    travel_to "2024-01-01"
    template = mail_templates(:bidding_round_completed)
    membership = memberships(:john)
    bidding_round = bidding_rounds(:open_2024)
    bidding_round.pledges.create!(
      membership: membership,
      basket_size_price: membership.basket_size.price + 1)

    mail = BiddingRoundMailer.with(
      template: template,
      member: membership.member,
      bidding_round: bidding_round,
    ).completed_email

    assert_equal "Bidding round #1 completed 🎉", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "bidding-round-completed", mail.tag
    assert_includes mail.body.to_s, "<p>Thank you for your pledge of CHF\u00A021.00 per basket."
    assert_includes mail.body.to_s, "<p>You can review the details of your membership at any time.</p>"
    assert_includes mail.body.to_s, "https://members.acme.test/memberships"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "failed_email" do
    travel_to "2024-01-01"
    template = mail_templates(:bidding_round_failed)
    membership = memberships(:john)
    bidding_round = bidding_rounds(:open_2024)
    bidding_round.pledges.create!(
      membership: membership,
      basket_size_price: membership.basket_size.price + 1)

    mail = BiddingRoundMailer.with(
      template: template,
      member: membership.member,
      bidding_round: bidding_round,
    ).failed_email

    assert_equal "Bidding round #1 failed 😬", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "bidding-round-failed", mail.tag
    assert_includes mail.body.to_s, "<p>You pledged CHF\u00A021.00 per basket.</p>"
    assert_includes mail.body.to_s, "<p>You can review the details of your membership at any time.</p>"
    assert_includes mail.body.to_s, "https://members.acme.test/memberships"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end
end
