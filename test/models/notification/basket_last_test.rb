# frozen_string_literal: true

require "test_helper"

class Notification::BasketLastTest < ActiveSupport::TestCase
  test "notify sends emails for last baskets" do
    cycle = DeliveryCycle.create!(
      delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at").merge(
        periods_attributes: [ { from_fy_month: 1, to_fy_month: 12 } ]
      )
    )
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_templates(:basket_last).update!(active: true, delivery_cycle_ids: cycle_ids)
    member1 = create_member
    member2 = create_member
    member3 = create_member

    travel_to "2024-04-01"
    create_membership(ended_on: "2024-04-01", last_basket_sent_at: nil).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: nil, member: member1).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: nil, member: create_member, delivery_cycle: cycle).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: nil, member: create_member, renew: false)
    create_membership(ended_on: "2024-04-15", last_basket_sent_at: nil, member: create_member).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: 1.minute.ago, member: create_member).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-15", last_basket_sent_at: nil, member: member2).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-15", last_basket_sent_at: nil, member: member3).update_columns(renewed_at: "2024-04-01", renew: true)
    create_absence(member: member2, started_on: "2024-04-08", ended_on: "2024-04-30")
    create_absence(member: member3, started_on: "2024-04-15", ended_on: "2024-04-30")

    travel_to "2024-04-08"
    assert_difference -> { BasketMailer.deliveries.size }, 2 do
      Notification::BasketLast.notify
      perform_enqueued_jobs
    end

    assert_equal Time.current, member1.membership.last_basket_sent_at

    mail = BasketMailer.deliveries.last
    assert_equal "Last basket of the year!", mail.subject
  end
end
