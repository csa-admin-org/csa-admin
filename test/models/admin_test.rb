# frozen_string_literal: true

require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "deletes sessions when destroyed" do
    admin = admins(:super)
    create_session(admin)

    assert_difference "Session.count", -1 do
      admin.destroy!
    end
  end

  test "sets latest_update_read on create" do
    admin = Admin.create!(
      name: "New Admin",
      permission: Permission.superadmin,
      email: "new_admin@example.com",
      latest_update_read: nil)

    assert_equal Update.all.first.name, admin.latest_update_read
  end

  test "email=" do
    admin = Admin.new(email: "Thibaud@Thibaud.GG ")

    assert_equal "thibaud@thibaud.gg", admin.email
  end

  test "notify! with suppressed email" do
    admin = admins(:ultra)
    admin.update!(notifications: [ "new_absence" ])
    EmailSuppression.suppress!(admin.email,
      stream_id: "outbound",
      origin: "Recipient",
      reason: "HardBounce")

    assert_no_difference("ActionMailer::Base.deliveries.count") do
      Admin.notify!(:new_absence)
      perform_enqueued_jobs
    end
  end

  test "notify! only once when _with_note and without _with_note enabled" do
    admin = admins(:ultra)
    admin.update!(notifications: [ "new_absence", "new_absence_with_note" ])

    assert_difference("ActionMailer::Base.deliveries.count", 1) do
      Admin.notify!(:new_absence)
      Admin.notify!(:new_absence_with_note)
      perform_enqueued_jobs
    end
  end
end
