# frozen_string_literal: true

require "test_helper"

class Notification::AdminNewActivityParticipationTest < ActiveSupport::TestCase
  def create_participation(attributes = {})
    activity = activities(:harvest)
    attributes[:member] ||= create_member
    ActivityParticipation.create!(activity: activity, **attributes)
  end

  test "notify sends emails to admins for new participations" do
    admin = admins(:ultra)
    admin.update(notifications: [ "new_activity_participation" ])

    member = create_member(emails: "anybody@doe.com")
    p1 = create_participation(member: member, activity: activities(:harvest))
    p2 = create_participation(member: member, activity: activities(:harvest_afternoon))
    create_participation(session: sessions(:ultra))
    create_participation(created_at: 2.days.ago)
    create_participation(admins_notified_at: Date.current)

    assert_difference -> { ActivityMailer.deliveries.size }, 1 do
      Notification::AdminNewActivityParticipation.notify
      perform_enqueued_jobs
    end

    mail = ActivityMailer.deliveries.last
    assert_equal "New participation in a ½ day", mail.subject
    assert_includes mail.html_part.body, "Schedule:</strong> 8:30-12:00, 13:30-17:00"
    assert_equal [ admin.email ], mail.to

    assert p1.reload.admins_notified_at?
    assert p2.reload.admins_notified_at?
  end

  test "notify sends email only for participations with note" do
    admin = admins(:ultra)
    admin.update(notifications: [ "new_activity_participation_with_note" ])

    member = create_member(emails: "anybody@doe.com")
    create_participation(activity: activities(:harvest))
    p = create_participation(
      member: member,
      activity: activities(:harvest),
      carpooling: true,
      carpooling_phone: "+41 79 123 45 67",
      carpooling_city: "Somwhere",
      note: "A great note!")

    assert_difference -> { ActivityMailer.deliveries.size }, 1 do
      Notification::AdminNewActivityParticipation.notify
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
