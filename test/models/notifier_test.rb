# frozen_string_literal: true

require "test_helper"

class NotifierTest < ActiveSupport::TestCase
  test "send_admin_memberships_renewal_pending_emails" do
    admins(:master).update(notifications: [ "memberships_renewal_pending" ])
    end_of_fiscal_year = Current.fiscal_year.end_of_year
    memberships(:john).update!(renew: true, renewal_opened_at: nil, renewed_at: nil)

    travel_to end_of_fiscal_year - 11.days
    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notifier.send_admin_memberships_renewal_pending_emails
      perform_enqueued_jobs
    end

    travel_to end_of_fiscal_year - 10.days
    assert_difference -> { AdminMailer.deliveries.size }, 1 do
      Notifier.send_admin_memberships_renewal_pending_emails
      perform_enqueued_jobs
    end

    travel_to end_of_fiscal_year - 7.days
    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notifier.send_admin_memberships_renewal_pending_emails
      perform_enqueued_jobs
    end

    travel_to end_of_fiscal_year - 4.days
    assert_difference -> { AdminMailer.deliveries.size }, 1 do
      Notifier.send_admin_memberships_renewal_pending_emails
      perform_enqueued_jobs
    end

    travel_to end_of_fiscal_year
    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notifier.send_admin_memberships_renewal_pending_emails
      perform_enqueued_jobs
    end
  end

  test "send_membership_initial_basket_emails" do
    cycle = DeliveryCycle.create!(delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at"))
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_template(:membership_initial_basket).update!(active: true, delivery_cycle_ids: cycle_ids)

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
    Absence.create!(member: member7, started_on: "2024-04-01", ended_on: "2024-04-08", admin: true)
    Absence.create!(member: member8, started_on: "2024-03-31", ended_on: "2024-04-01", admin: true)

    travel_to "2024-04-08"
    assert_difference -> { MembershipMailer.deliveries.size }, 3 do
      Notifier.send_membership_initial_basket_emails
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

  test "send_membership_final_basket_emails" do
    cycle = DeliveryCycle.create!(delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at"))
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_template(:membership_final_basket).update!(active: true, delivery_cycle_ids: cycle_ids)

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
    Absence.create!(member: member6, started_on: "2024-05-27", ended_on: "2024-06-30", admin: true)
    Absence.create!(member: member7, started_on: "2024-06-03", ended_on: "2024-06-30", admin: true)

    travel_to "2024-05-27"
    assert_difference -> { MembershipMailer.deliveries.size }, 3 do
      Notifier.send_membership_final_basket_emails
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

  test "send_membership_first_basket_emails" do
    cycle = DeliveryCycle.create!(delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at"))
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_template(:membership_first_basket).update!(active: true, delivery_cycle_ids: cycle_ids)
    member1 = create_member
    member2 = create_member
    member3 = create_member

    travel_to "2024-04-01"
    create_membership(started_on: "2024-04-01", first_basket_sent_at: nil)
    create_membership(started_on: "2024-04-08", first_basket_sent_at: nil, member: member1)
    create_membership(started_on: "2024-04-01", first_basket_sent_at: nil, delivery_cycle: cycle)
    create_membership(started_on: "2024-04-15", first_basket_sent_at: nil)
    create_membership(started_on: "2024-04-08", first_basket_sent_at: 1.minute.ago)
    create_membership(started_on: "2024-04-08", first_basket_sent_at: nil, member: member2)
    create_membership(started_on: "2024-04-01", first_basket_sent_at: nil, member: member3)
    Absence.create!(member: member2, started_on: "2024-04-01", ended_on: "2024-04-08", admin: true)
    Absence.create!(member: member3, started_on: "2024-03-31", ended_on: "2024-04-01", admin: true)

    travel_to "2024-04-08"
    assert_difference -> { MembershipMailer.deliveries.size }, 2 do
      Notifier.send_membership_first_basket_emails
      perform_enqueued_jobs
    end

    assert_equal Time.current, member1.membership.first_basket_sent_at

    mail = MembershipMailer.deliveries.last
    assert_equal "First basket of the year!", mail.subject
  end

  test "send_membership_last_basket_emails" do
    cycle = DeliveryCycle.create!(delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at"))
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_template(:membership_last_basket).update!(active: true, delivery_cycle_ids: cycle_ids)
    member1 = create_member
    member2 = create_member
    member3 = create_member

    travel_to "2024-04-01"
    create_membership(ended_on: "2024-04-01", last_basket_sent_at: nil).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: nil, member: member1).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: nil, delivery_cycle: cycle).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: nil, renew: false)
    create_membership(ended_on: "2024-04-15", last_basket_sent_at: nil).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-08", last_basket_sent_at: 1.minute.ago).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-15", last_basket_sent_at: nil, member: member2).update_columns(renewed_at: "2024-04-01", renew: true)
    create_membership(ended_on: "2024-04-15", last_basket_sent_at: nil, member: member3).update_columns(renewed_at: "2024-04-01", renew: true)
    Absence.create!(member: member2, started_on: "2024-04-08", ended_on: "2024-04-30", admin: true)
    Absence.create!(member: member3, started_on: "2024-04-15", ended_on: "2024-04-30", admin: true)

    travel_to "2024-04-08"
    assert_difference -> { MembershipMailer.deliveries.size }, 2 do
      Notifier.send_membership_last_basket_emails
      perform_enqueued_jobs
    end

    assert_equal Time.current, member1.membership.last_basket_sent_at

    mail = MembershipMailer.deliveries.last
    assert_equal "Last basket of the year!", mail.subject
  end

  test "send_membership_last_trial_basket_emails" do
    cycle = DeliveryCycle.create!(delivery_cycles(:mondays).attributes.except("id", "created_at", "updated_at"))
    cycle_ids = DeliveryCycle.pluck(:id) - [ cycle.id ]

    mail_template(:membership_last_trial_basket).update!(active: true, delivery_cycle_ids: cycle_ids)
    member = create_member(emails: "bob@doe.com")

    travel_to "2024-04-01"
    create_membership(started_on: "2024-04-01")
    create_membership(started_on: "2024-04-15")
    create_membership(started_on: "2024-04-08", member: member)
    create_membership(started_on: "2024-04-08", delivery_cycle: cycle)
    create_membership(started_on: "2024-04-08", ended_on: "2024-04-15")
    create_membership(started_on: "2024-04-08", last_trial_basket_sent_at: 1.minute.ago)

    travel_to "2024-04-15"
    assert_difference -> { MembershipMailer.deliveries.size }, 1 do
      Notifier.send_membership_last_trial_basket_emails
      perform_enqueued_jobs
    end

    assert_equal Time.current, member.membership.last_trial_basket_sent_at

    mail = MembershipMailer.deliveries.last
    assert_equal "Last trial basket!", mail.subject
    assert_equal [ "bob@doe.com" ], mail.to
  end

  test "send_membership_renewal_reminder_emails" do
    org(open_renewal_reminder_sent_after_in_days: 10)
    mail_template(:membership_renewal_reminder).update!(active: true)
    member = create_member(emails: "bob@doe.com")

    travel_to "2024-01-01"
    create_membership(renewal_opened_at: nil)
    create_membership(renewal_opened_at: "2024-09-01").update_columns(renewed_at: "2024-09-02")
    create_membership(renewal_opened_at: "2024-09-01", member: member)
    create_membership(renewal_opened_at: "2024-09-01", renewal_reminder_sent_at: "2024-09-10")
    travel_to "2023-01-01"
    create_membership(renewal_opened_at: "2024-09-01")

    travel_to "2024-09-11"
    assert_difference -> { MembershipMailer.deliveries.size }, 1 do
      Notifier.send_membership_renewal_reminder_emails
      perform_enqueued_jobs
    end

    mail = MembershipMailer.deliveries.last
    assert_equal "Renew your membership (reminder)", mail.subject
    assert_equal [ "bob@doe.com" ], mail.to
  end

  def create_participation(attributes = {})
    activity = activities(:harvest_help)
    create_activity_participation(activity: activity, **attributes)
  end

  test "send_activity_participation_validated_emails" do
    mail_template(:activity_participation_validated).update!(active: true)
    member = create_member(emails: "bob@doe.com")

    create_participation(review_sent_at: nil, validated_at: 1.day.ago, member: member)
    create_participation(review_sent_at: nil, rejected_at: 1.day.ago)
    create_participation(review_sent_at: Time.current, validated_at: 1.day.ago)
    create_participation(review_sent_at: nil, validated_at: 4.days.ago)

    assert_difference -> { ActivityMailer.deliveries.size }, 1 do
      Notifier.send_activity_participation_validated_emails
      perform_enqueued_jobs
    end

    mail = ActivityMailer.deliveries.last
    assert_equal "Activity confirmed 🎉", mail.subject
    assert_equal [ "bob@doe.com" ], mail.to
  end

  test "does not send activity_participation_validated email when template is not active" do
    mail_template(:activity_participation_validated).update!(active: false)

    create_participation(review_sent_at: nil, validated_at: 1.day.ago)

    assert_no_difference -> { ActivityMailer.deliveries.size } do
      Notifier.send_activity_participation_validated_emails
      perform_enqueued_jobs
    end
  end

  test "send_activity_participation_rejected_emails" do
    mail_template(:activity_participation_rejected).update!(active: true)
    member = create_member(emails: "bob@doe.com")

    create_participation(review_sent_at: nil, rejected_at: 1.day.ago, member: member)
    create_participation(review_sent_at: nil, validated_at: 1.day.ago)
    create_participation(review_sent_at: Time.current, rejected_at: 1.day.ago)
    create_participation(review_sent_at: nil, rejected_at: 4.days.ago)

    assert_difference -> { ActivityMailer.deliveries.size }, 1 do
      Notifier.send_activity_participation_rejected_emails
      perform_enqueued_jobs
    end

    mail = ActivityMailer.deliveries.last
    assert_equal "Activity rejected 😬", mail.subject
    assert_equal [ "bob@doe.com" ], mail.to
  end

  test "does not send activity_participation_rejected email when template is not active" do
    mail_template(:activity_participation_rejected).update!(active: false)

    create_participation(review_sent_at: nil, rejected_at: 1.day.ago)

    assert_no_difference -> { ActivityMailer.deliveries.size } do
      Notifier.send_activity_participation_rejected_emails
      perform_enqueued_jobs
    end
  end

  test "send_admin_new_activity_participation_emails" do
    admin = admins(:master)
    admin.update(notifications: [ "new_activity_participation" ])

    member = create_member(emails: "bob@doe.com")
    p1 = create_participation(member: member, activity: activities(:harvest_help))
    p2 = create_participation(member: member, activity: activities(:harvest_help_afternoon))
    create_participation(session: sessions(:master))
    create_participation(created_at: 2.days.ago)
    create_participation(admins_notified_at: Date.today)

    assert_difference -> { ActivityMailer.deliveries.size }, 1 do
      Notifier.send_admin_new_activity_participation_emails
      perform_enqueued_jobs
    end

    mail = ActivityMailer.deliveries.last
    assert_equal "New participation in a ½ day", mail.subject
    assert_includes mail.html_part.body, "Schedule:</strong> 8:30-12:00, 13:30-17:00"
    assert_equal [ admin.email ], mail.to

    assert p1.reload.admins_notified_at?
    assert p2.reload.admins_notified_at?
  end

  test "only notify participation with note" do
    admin = admins(:master)
    admin.update(notifications: [ "new_activity_participation_with_note" ])

    member = create_member(emails: "bob@doe.com")
    create_participation(activity: activities(:harvest_help))
    p = create_participation(
      member: member,
      activity: activities(:harvest_help),
      carpooling: true,
      carpooling_phone: "+41 79 123 45 67",
      carpooling_city: "Somwhere",
      note: "A great note!")

    assert_difference -> { ActivityMailer.deliveries.size }, 1 do
      Notifier.send_admin_new_activity_participation_emails
      perform_enqueued_jobs
    end

    mail = ActivityMailer.deliveries.last
    assert_equal "New participation in a ½ day", mail.subject
    assert_includes mail.html_part.body, "Carpooling"
    assert_includes mail.html_part.body, "A great note!"
    assert_equal [ admin.email ], mail.to

    assert p.reload.admins_notified_at.present?
  end
end
