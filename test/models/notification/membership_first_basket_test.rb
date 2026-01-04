# frozen_string_literal: true

require "test_helper"

class Notification::MembershipFirstBasketTest < ActiveSupport::TestCase
  test "notify sends emails for first baskets" do
    cycle = DeliveryCycle.create!(
      delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at").merge(
        periods_attributes: [ { from_fy_month: 1, to_fy_month: 12 } ]
      )
    )
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_templates(:membership_first_basket).update!(active: true, delivery_cycle_ids: cycle_ids)
    member1 = create_member
    member2 = create_member
    member3 = create_member

    travel_to "2024-04-01"
    create_membership(started_on: "2024-04-01", first_basket_sent_at: nil)
    create_membership(started_on: "2024-04-08", first_basket_sent_at: nil, member: member1)
    create_membership(started_on: "2024-04-01", first_basket_sent_at: nil, member: create_member, delivery_cycle: cycle)
    create_membership(started_on: "2024-04-15", first_basket_sent_at: nil, member: create_member)
    create_membership(started_on: "2024-04-08", first_basket_sent_at: 1.minute.ago, member: create_member)
    create_membership(started_on: "2024-04-08", first_basket_sent_at: nil, member: member2)
    create_membership(started_on: "2024-04-01", first_basket_sent_at: nil, member: member3)
    create_absence(member: member2, started_on: "2024-04-01", ended_on: "2024-04-08")
    create_absence(member: member3, started_on: "2024-03-31", ended_on: "2024-04-01")

    travel_to "2024-04-08"
    assert_difference -> { MembershipMailer.deliveries.size }, 2 do
      Notification::MembershipFirstBasket.notify
      perform_enqueued_jobs
    end

    assert_equal Time.current, member1.membership.first_basket_sent_at

    mail = MembershipMailer.deliveries.last
    assert_equal "First basket of the year!", mail.subject
  end
end
