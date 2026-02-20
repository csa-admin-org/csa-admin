# frozen_string_literal: true

require "test_helper"

class Notification::BasketInitialTest < ActiveSupport::TestCase
  test "notify sends emails for initial baskets" do
    cycle = DeliveryCycle.create!(
      delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at").merge(
        periods_attributes: [ { from_fy_month: 1, to_fy_month: 12 } ]
      )
    )
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_templates(:basket_initial).update!(active: true, delivery_cycle_ids: cycle_ids)

    member1 = create_member
    member2 = create_member
    member2_bis = create_member
    member3 = create_member
    member4 = create_member(initial_basket_sent_at: "2022-01-01", activated_at: "2024-04-01")
    member5 = create_member(initial_basket_sent_at: "2024-04-01", activated_at: "2024-04-01")
    member6 = create_member
    member7 = create_member
    member8 = create_member

    travel_to "2023-01-01"
    create_membership(member: member6).update_column(:renewed_at, "2023-11-01")

    travel_to "2024-04-01"
    create_membership(started_on: "2024-04-01", member: member1)
    create_membership(started_on: "2024-04-08", member: member2)
    create_membership(started_on: "2024-04-08", member: member2_bis, delivery_cycle: cycle)
    create_membership(started_on: "2024-04-15", member: member3)
    create_membership(started_on: "2024-04-08", member: member4)
    create_membership(started_on: "2024-04-08", member: member5)
    create_membership(started_on: "2024-04-08", member: member6)
    create_membership(started_on: "2024-04-08", member: member7)
    create_membership(started_on: "2024-04-01", member: member8)
    create_absence(member: member7, started_on: "2024-04-01", ended_on: "2024-04-08")
    create_absence(member: member8, started_on: "2024-03-31", ended_on: "2024-04-01")

    travel_to "2024-04-08"
    assert_difference -> { BasketMailer.deliveries.size }, 3 do
      Notification::BasketInitial.notify
      perform_enqueued_jobs
    end

    assert_nil member1.reload.initial_basket_sent_at
    assert_equal Time.current, member2.reload.initial_basket_sent_at
    assert_nil member2_bis.reload.initial_basket_sent_at
    assert_nil member3.reload.initial_basket_sent_at
    assert_equal Time.current, member4.reload.initial_basket_sent_at
    assert_equal "2024-04-01", member5.reload.initial_basket_sent_at.to_date.to_s
    assert_nil member6.reload.initial_basket_sent_at
    assert_nil member7.reload.initial_basket_sent_at
    assert_equal Time.current, member8.reload.initial_basket_sent_at
  end
end
