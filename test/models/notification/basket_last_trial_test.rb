# frozen_string_literal: true

require "test_helper"

class Notification::BasketLastTrialTest < ActiveSupport::TestCase
  test "notify sends emails for last trial baskets" do
    cycle = DeliveryCycle.create!(
      delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at").merge(
        periods_attributes: [ { from_fy_month: 1, to_fy_month: 12 } ]
      )
    )
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_templates(:basket_last_trial).update!(active: true, delivery_cycle_ids: cycle_ids)
    member = create_member(emails: "anybody@doe.com")

    travel_to "2024-04-01"
    create_membership(started_on: "2024-04-01")
    create_membership(started_on: "2024-04-15", member: create_member)
    create_membership(started_on: "2024-04-08", member: member)
    create_membership(started_on: "2024-04-08", member: create_member, delivery_cycle: cycle)
    create_membership(started_on: "2024-04-08", member: create_member, ended_on: "2024-04-15")
    create_membership(started_on: "2024-04-08", member: create_member, last_trial_basket_sent_at: 1.minute.ago)

    travel_to "2024-04-15"
    assert_difference -> { BasketMailer.deliveries.size }, 1 do
      Notification::BasketLastTrial.notify
      perform_enqueued_jobs
    end

    assert_equal Time.current, member.membership.last_trial_basket_sent_at

    mail = BasketMailer.deliveries.last
    assert_equal "Last trial basket!", mail.subject
    assert_equal [ "anybody@doe.com" ], mail.to
  end
end
