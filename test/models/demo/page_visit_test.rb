# frozen_string_literal: true

require "test_helper"

class Demo::PageVisitTest < ActiveSupport::TestCase
  setup do
    @admin = admins(:ultra)
    @session = sessions(:ultra)
  end

  test "valid page visit" do
    visit = Demo::PageVisit.new(
      admin: @admin,
      session: @session,
      path: "/members",
      controller_name: "members",
      action_name: "index",
      page_key: "members#index",
      status: 200)

    assert visit.valid?
    assert visit.meaningful?
  end

  test "requires page details" do
    visit = Demo::PageVisit.new(admin: @admin, session: @session)

    assert_not visit.valid?
    assert_includes visit.errors[:path], I18n.t("errors.messages.blank")
    assert_includes visit.errors[:controller_name], I18n.t("errors.messages.blank")
    assert_includes visit.errors[:action_name], I18n.t("errors.messages.blank")
    assert_includes visit.errors[:page_key], I18n.t("errors.messages.blank")
    assert_includes visit.errors[:status], I18n.t("errors.messages.blank")
  end

  test "page_key_for joins controller path and action" do
    assert_equal "members#show", Demo::PageVisit.page_key_for("members", "show")
  end

  test "meaningful scope excludes dashboard visits" do
    meaningful = create_page_visit(page_key: "members#index")
    create_page_visit(page_key: "dashboard#index")

    assert_equal [ meaningful ], Demo::PageVisit.meaningful.to_a
  end

  test "admin demo exploration helpers" do
    assert_not @admin.meaningfully_explored_demo?

    travel_to 3.hours.ago do
      create_page_visit(page_key: "dashboard#index")
    end
    assert_not @admin.meaningfully_explored_demo?

    travel_to 2.hours.ago do
      create_page_visit(page_key: "members#index")
    end
    assert_not @admin.meaningfully_explored_demo?

    travel_to 1.hour.ago do
      create_page_visit(page_key: "admins#index")
    end

    assert @admin.meaningfully_explored_demo?
    assert_equal 3, @admin.demo_page_visits_count
    assert_equal 2, @admin.demo_meaningful_page_visits_count
    assert_equal 2, @admin.demo_distinct_meaningful_page_keys_count
    assert_equal 1.hour.ago.to_i, @admin.last_demo_page_visit_at.to_i
  end

  private

  def create_page_visit(page_key:)
    Demo::PageVisit.create!(
      admin: @admin,
      session: @session,
      path: "/#{page_key.delete_suffix("#index")}",
      controller_name: page_key.split("#").first,
      action_name: page_key.split("#").last,
      page_key: page_key,
      status: 200)
  end
end
