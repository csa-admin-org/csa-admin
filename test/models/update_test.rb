# frozen_string_literal: true

require "test_helper"

class UpdateTest < ActiveSupport::TestCase
  test "name does not include locale" do
    updates = Update.all
    assert_not_includes updates.first.name, ".#{I18n.locale}"
  end

  test "unread_count" do
    updates = Update.all

    admin = Admin.new(latest_update_read: nil)
    assert_equal updates.size, Update.unread_count(admin)

    admin.latest_update_read = updates.first(2).last.name
    assert_equal 1, Update.unread_count(admin)
  end

  test "mark_as_read!" do
    updates = Update.all
    admin = admins(:master)
    admin.update!(latest_update_read: nil)

    assert_changes -> { admin.reload.latest_update_read }, from: nil, to: updates.first.name do
      Update.mark_as_read!(admin)
    end
  end
end
