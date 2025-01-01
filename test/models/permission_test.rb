# frozen_string_literal: true

require "test_helper"

class PermissionTest < ActiveSupport::TestCase
  test "can only write editable features" do
    permission = Permission.new(rights: {
      admin: :write,
      member: :write
    })
    assert_equal({ "member" => "write" }, permission.rights)
  end

  test "superadmin" do
    permission = permissions(:super_admin)
    assert permission.rights.empty?
    assert permission.superadmin?
    assert permission.can_write?(:organization)
    assert permission.can_write?(:comment)
    assert permission.can_write?(:basket_size)
    assert_not permission.can_destroy?
    assert_not permission.can_update?
  end
end
