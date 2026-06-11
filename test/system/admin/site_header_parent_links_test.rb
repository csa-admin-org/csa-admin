# frozen_string_literal: true

require "application_system_test_case"

class SiteHeaderParentLinksTest < ApplicationSystemTestCase
  include ActiveAdmin::MenuBadgeHelper

  test "desktop parent menus link to first child except other" do
    Shop::Order.pending.update_all(state: "invoiced")
    ActivityParticipation.pending.update_all(state: "validated")

    login admins(:super)
    visit "/"

    within "li[data-item-id='navshop']" do
      assert_selector "a#dropdownHoverButton-navshop[href='#{smart_or_pending_shop_orders_path}']"
    end

    within "li[data-item-id='activities_human_name']" do
      assert_selector "a#dropdownHoverButton-activities_human_name[href='#{current_year_or_pending_activity_participations_path}']"
    end

    within "li[data-item-id='navbilling']" do
      assert_selector "a#dropdownHoverButton-navbilling[href='#{invoices_path}']"
    end

    within "li[data-item-id='email']" do
      assert_selector "a#dropdownHoverButton-email[href='#{newsletters_path}']"
    end

    within "li[data-item-id='other']" do
      assert_selector "button#dropdownHoverButton-other"
      assert_no_selector "a#dropdownHoverButton-other"
    end
  end

  test "parent quick access links to pending scope when badge is present" do
    travel_to "2024-09-01" do
      pending_shop_orders_path = shop_orders_path(
        scope: :pending,
        q: { _delivery_gid_eq: Shop::Order.pending.first.delivery_gid })

      login admins(:super)
      visit "/"

      within "li[data-item-id='navshop']" do
        assert_selector "a#dropdownHoverButton-navshop[href='#{pending_shop_orders_path}']"
      end

      within "li[data-item-id='activities_human_name']" do
        assert_selector "a#dropdownHoverButton-activities_human_name[href='#{activity_participations_path(scope: :pending)}']"
      end
    end
  end
end
