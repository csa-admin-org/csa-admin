# frozen_string_literal: true

require "test_helper"

class Notification::BasketFinalTest < ActiveSupport::TestCase
  test "notify sends emails for final baskets" do
    cycle = DeliveryCycle.create!(
      delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at").merge(
        periods_attributes: [ { from_fy_month: 1, to_fy_month: 12 } ]
      )
    )
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_templates(:basket_final).update!(active: true, delivery_cycle_ids: cycle_ids)

    member1 = create_member
    member2 = create_member
    member2_bis = create_member
    member3 = create_member
    member4 = create_member(final_basket_sent_at: "2022-01-01", activated_at: "2024-01-01")
    member5 = create_member(final_basket_sent_at: "2024-03-31", activated_at: "2024-01-01")
    member6 = create_member
    member7 = create_member

    travel_to "2024-04-01"
    create_membership(ended_on: "2024-05-27", member: member1).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-05-27", member: member2, renew: false)
    create_membership(ended_on: "2024-05-27", member: member2_bis, delivery_cycle: cycle, renew: false)
    create_membership(ended_on: "2024-06-03", member: member3, renew: false)
    create_membership(ended_on: "2024-05-27", member: member4, renew: false)
    create_membership(ended_on: "2024-05-27", member: member5, renew: false)
    create_membership(ended_on: "2024-05-27", member: member6)
    create_membership(ended_on: "2024-06-03", member: member7)
    create_absence(member: member6, started_on: "2024-05-27", ended_on: "2024-06-30")
    create_absence(member: member7, started_on: "2024-06-03", ended_on: "2024-06-30")

    travel_to "2024-05-27"
    assert_difference -> { BasketMailer.deliveries.size }, 6 do
      Notification::BasketFinal.notify
      perform_enqueued_jobs
    end

    assert_nil member1.reload.final_basket_sent_at
    assert_equal Time.current, member2.reload.final_basket_sent_at
    assert_nil member2_bis.reload.initial_basket_sent_at
    assert_nil member3.reload.final_basket_sent_at
    assert_equal Time.current, member4.reload.final_basket_sent_at
    assert_equal "2024-03-31", member5.reload.final_basket_sent_at.to_date.to_s
    assert_nil member6.reload.final_basket_sent_at
    assert_equal Time.current, member7.reload.final_basket_sent_at
  end
end
