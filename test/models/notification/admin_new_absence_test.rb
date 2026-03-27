# frozen_string_literal: true

require "test_helper"

class Notification::AdminNewAbsenceTest < ActiveSupport::TestCase
  test "notify sends emails to admins for new absences" do
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
    absence.update_column(:created_at, 10.minutes.ago)

    assert_difference -> { AdminMailer.deliveries.size }, 1 do
      Notification::AdminNewAbsence.notify
      perform_enqueued_jobs
    end

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

    assert absence.reload.admins_notified_at?
  end

  test "notify sends email only for absences with note" do
    admin1 = admins(:ultra)
    admin2 = admins(:super)
    admin3 = admins(:external)
    admin1.update_column(:notifications, %w[new_absence])
    admin2.update_column(:notifications, %w[new_absence_with_note])
    admin3.update_column(:notifications, %w[])

    absence = create_absence(
      session: sessions(:ultra),
      member: members(:john),
      note: "A Super Note!",
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    absence.update_column(:created_at, 10.minutes.ago)

    assert_difference -> { AdminMailer.deliveries.size }, 1 do
      Notification::AdminNewAbsence.notify
      perform_enqueued_jobs
    end

    mail = AdminMailer.deliveries.last
    assert_equal "New absence", mail.subject
    assert_equal [ admin2.email ], mail.to
    assert_equal [ sessions(:ultra).email, "john@doe.com" ], mail.reply_to
    body = mail.html_part.body
    assert_includes body, admin2.name
    assert_includes body, absence.member.name
    assert_includes body, I18n.l(absence.started_on)
    assert_includes body, I18n.l(absence.ended_on)
    assert_includes body, "Member's note:"
    assert_includes body, "A Super Note!"

    assert absence.reload.admins_notified_at?
  end

  test "notify sets reply_to with session email and member emails when note is present" do
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
    absence.update_column(:created_at, 10.minutes.ago)

    assert_difference -> { AdminMailer.deliveries.size }, 1 do
      Notification::AdminNewAbsence.notify
      perform_enqueued_jobs
    end

    mail = AdminMailer.deliveries.last
    assert_equal [ session.email, *member.emails_array ].compact.uniq, mail.reply_to

    assert absence.reload.admins_notified_at?
  end

  test "notify skips absences created less than 5 minutes ago" do
    admin = admins(:ultra)
    admin.update_column(:notifications, %w[new_absence])

    create_absence(
      member: members(:john),
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)

    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notification::AdminNewAbsence.notify
      perform_enqueued_jobs
    end
  end

  test "notify skips already notified absences" do
    admin = admins(:ultra)
    admin.update_column(:notifications, %w[new_absence])

    absence = create_absence(
      member: members(:john),
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    absence.update_columns(created_at: 10.minutes.ago, admins_notified_at: Time.current)

    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notification::AdminNewAbsence.notify
      perform_enqueued_jobs
    end
  end

  test "notify skips absences created more than 1 day ago" do
    admin = admins(:ultra)
    admin.update_column(:notifications, %w[new_absence])

    absence = create_absence(
      member: members(:john),
      started_on: 1.week.from_now,
      ended_on: 2.weeks.from_now)
    absence.update_column(:created_at, 2.days.ago)

    assert_no_difference -> { AdminMailer.deliveries.size } do
      Notification::AdminNewAbsence.notify
      perform_enqueued_jobs
    end
  end
end
