# frozen_string_literal: true

require "test_helper"

class DemoPageVisitTrackingTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    @admin = admins(:ultra)
  end

  test "tracks authenticated demo admin page visits" do
    with_demo_tenant do
      login(@admin)

      assert_difference "Demo::PageVisit.count", 1 do
        get root_path
      end

      visit = Demo::PageVisit.last
      assert_equal @admin, visit.admin
      assert_equal @admin.sessions.active.last, visit.session
      assert_equal "/", visit.path
      assert_equal "dashboard", visit.controller_name
      assert_equal "index", visit.action_name
      assert_equal "dashboard#index", visit.page_key
      assert_equal 200, visit.status
      assert_not visit.meaningful?
    end
  end

  test "does not track outside demo tenants" do
    login(@admin)

    assert_no_difference "Demo::PageVisit.count" do
      get root_path
    end
  end

  test "does not track unauthenticated demo requests" do
    with_demo_tenant do
      assert_no_difference "Demo::PageVisit.count" do
        get root_path
      end
    end
  end

  test "does not track mutating demo requests" do
    with_demo_tenant do
      login(@admin)

      assert_no_difference "Demo::PageVisit.count" do
        delete logout_path
      end
    end
  end

  test "does not track ignored demo controllers" do
    with_demo_tenant do
      assert_no_difference "Demo::PageVisit.count" do
        get login_path
      end
    end
  end

  private

  def login(admin)
    session = Session.create!(
      admin: admin,
      email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")

    get session_path(session.generate_token_for(:redeem))
    assert_redirected_to root_path
  end
end
