# frozen_string_literal: true

require "application_system_test_case"

class SiteHeaderBadgesTest < ApplicationSystemTestCase
  test "shows pending badges and points resource links to pending scopes" do
    travel_to "2024-09-01" do
      login admins(:super)
      visit "/"

      within "#navbar-dropdown" do
        assert_selector "[data-menu-badge='members']", text: Member.pending.count.to_s, minimum: 1
        assert_selector "[data-menu-badge='shop']", text: Shop::Order.pending.count.to_s, minimum: 1
        assert_selector "[data-menu-badge='activities']", text: ActivityParticipation.pending.count.to_s, minimum: 1

        assert_selector "a[href='#{members_path(scope: :pending)}'] > [data-menu-badge='members']", text: Member.pending.count.to_s
        assert_selector "li[data-item-id='shop_orders'] a > [data-menu-badge='shop']", text: Shop::Order.pending.count.to_s
        assert_selector "li[data-item-id='activity_participations'] a > [data-menu-badge='activities']", text: ActivityParticipation.pending.count.to_s

        assert_selector "a[href='#{members_path(scope: :pending)}']", minimum: 1
        assert_selector "a[href='#{shop_orders_path(scope: :pending)}']", minimum: 1
        assert_selector "a[href='#{activity_participations_path(scope: :pending)}']", minimum: 1
      end
    end
  end

  test "hides pending badges when counts are zero" do
    travel_to "2024-09-01" do
      Member.pending.update_all(state: "active")
      Shop::Order.pending.update_all(state: "invoiced")
      ActivityParticipation.pending.update_all(state: "validated")

      login admins(:super)
      visit "/"

      within "#navbar-dropdown" do
        assert_no_selector "[data-menu-badge]"
      end
    end
  end
end
