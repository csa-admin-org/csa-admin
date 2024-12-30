# frozen_string_literal: true

require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "deletes sessions when destroyed" do
    admin = admins(:super)
    session = create_session(admin)

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
    admin = admins(:super)
    admin.update!(notifications: [ "new_absence" ])
    EmailSuppression.suppress!(admin.email,
      stream_id: "outbound",
      origin: "Recipient",
      reason: "HardBounce")

    assert_no_difference("ActionMailer::Base.deliveries.count") do
      Admin.notify!(:new_absence)
    end
  end
end
