# frozen_string_literal: true

require "test_helper"

class Absence::AdminNotificationsTest < ActiveSupport::TestCase
  test "notifies admin with new_absence notifications on when created" do
    admin1 = admins(:ultra)
    admin2 = admins(:super)
    admin3 = admins(:external)
    admin1.update_column(:notifications, %w[new_absence])
    admin2.update_column(:notifications, %w[new_absence_with_note])
    admin3.update_column(:notifications, %w[])

    absence = create_absence(
      member: members(:john),
      note: " ",
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    perform_enqueued_jobs

    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "New absence", mail.subject
    assert_equal [ admin1.email ], mail.to
    assert_nil mail.reply_to
    body = mail.html_part.body
    assert_includes body, admin1.name
    assert_includes body, absence.member.name
    assert_includes body, I18n.l(absence.started_on)
    assert_includes body, I18n.l(absence.ended_on)
    assert_not_includes body, "Member's note:"
  end

  test "only notifies admin with new_absence_with_note notifications when note is present" do
    admin1 = admins(:ultra)
    admin2 = admins(:super)
    admin3 = admins(:external)
    admin1.update_column(:notifications, %w[new_absence])
    admin2.update_column(:notifications, %w[new_absence_with_note])
    admin3.update_column(:notifications, %w[])

    absence = create_absence(
      admin: admin1,
      member: members(:john),
      note: "A Super Note!",
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    perform_enqueued_jobs

    assert_equal 1, AdminMailer.deliveries.size
    mail = AdminMailer.deliveries.last
    assert_equal "New absence", mail.subject
    assert_equal [ admin2.email ], mail.to
    assert_equal [ "john@doe.com" ], mail.reply_to
    body = mail.html_part.body
    assert_includes body, admin2.name
    assert_includes body, absence.member.name
    assert_includes body, I18n.l(absence.started_on)
    assert_includes body, I18n.l(absence.ended_on)
    assert_includes body, "Member's note:"
    assert_includes body, "A Super Note!"
  end

  test "sets reply_to with session email and member emails when note is present" do
    admin = admins(:ultra)
    admin.update_column(:notifications, %w[new_absence])

    member = members(:john)
    session = sessions(:john)

    absence = create_absence(
      member: member,
      session: session,
      note: "Please call me back",
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    perform_enqueued_jobs

    mail = AdminMailer.deliveries.last
    assert_equal [ session.email, *member.emails_array ].compact.uniq, mail.reply_to
  end
end
