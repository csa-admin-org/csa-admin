# frozen_string_literal: true

require "test_helper"

class Notification::BiddingRoundOpenedReminderTest < ActiveSupport::TestCase
  test "notify sends reminder emails after delay" do
    org(features: [ "bidding_round" ], open_bidding_round_reminder_sent_after_in_days: 5)
    mail_templates(:bidding_round_opened_reminder).update!(active: true)

    travel_to "2024-01-01"
    bidding_round = bidding_rounds(:open_2024)
    bidding_round.update!(created_at: "2024-01-01")
    assert_equal 4, bidding_round.eligible_memberships_count

    memberships(:john).touch(:bidding_round_opened_reminder_sent_at)

    travel_to "2024-01-07"

    bidding_round.pledges.create!(
      membership: memberships(:bob),
      basket_size_price: memberships(:bob).basket_size.price + 1)
    memberships(:anna).touch(:bidding_round_opened_reminder_sent_at)

    assert_difference -> { BiddingRoundMailer.deliveries.size }, 2 do
      assert_no_changes -> { memberships(:anna).bidding_round_opened_reminder_sent_at } do
        Notification::BiddingRoundOpenedReminder.notify
        perform_enqueued_jobs
      end
    end

    refute memberships(:bob).bidding_round_opened_reminder_sent_at?

    mail = BiddingRoundMailer.deliveries.first
    assert_equal "Bidding round #1 is open (reminder)", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert memberships(:john).bidding_round_opened_reminder_sent_at?

    mail = BiddingRoundMailer.deliveries.last
    assert_equal "Bidding round #1 is open (reminder)", mail.subject
    assert_equal [ "jane@doe.com" ], mail.to
    assert memberships(:jane).bidding_round_opened_reminder_sent_at?

    travel_to "2024-01-08"
    assert_no_difference -> { BiddingRoundMailer.deliveries.size } do
      Notification::BiddingRoundOpenedReminder.notify
      perform_enqueued_jobs
    end
  end
end
