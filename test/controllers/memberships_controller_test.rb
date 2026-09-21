# frozen_string_literal: true

require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "basket size edit warns when current or future memberships keep their price" do
    travel_to "2024-05-01"
    login admins(:super)

    get edit_basket_size_path(basket_sizes(:medium))

    assert_response :success
    assert_select ".admin-warning-pane", text: /keep their existing price/
  end

  test "new delivery warns when extra fiscal year deliveries already exist" do
    travel_to "2024-05-01"
    Delivery.insert({
      date: Date.new(2026, 1, 5),
      created_at: Time.current,
      updated_at: Time.current
    })
    login admins(:super)

    get new_delivery_path

    assert_response :success
    assert_select ".admin-warning-pane", text: /makes renewal target that year/
  end

  test "basket size edit does not warn when no current or future memberships remain" do
    travel_to "2024-05-01"
    login admins(:super)

    get edit_basket_size_path(basket_sizes(:small))

    assert_response :success
    assert_select ".admin-warning-pane", false
  end

  test "index renders activity and billing sidebars" do
    travel_to "2024-05-01"
    login admins(:super)

    get memberships_path, params: {
      q: {
        activity_participations_accepted_gt: 0,
        during_year: 2024
      }
    }

    assert_response :success
    assert_select "label[for=q_member_city]", text: Member.human_attribute_name(:city)

    get memberships_path(format: :csv)
    assert_response :success
  end

  test "index filters memberships by member city" do
    travel_to "2024-05-01"
    members(:jane).update!(city: "Lausanne")
    login admins(:super)

    get memberships_path, params: {
      q: { member_city_eq: "Lausanne" },
      scope: :all
    }

    assert_response :success
    assert_select "td a[href='#{membership_path(memberships(:jane))}']"
    assert_select "td a[href='#{membership_path(memberships(:john))}']", false
  end

  test "index CSV includes member city" do
    travel_to "2024-05-01"
    members(:jane).update!(city: "Lausanne")
    login admins(:super)

    get memberships_path(format: :csv), params: {
      q: { during_year: 2024 },
      scope: :all
    }

    assert_response :success
    csv = CSV.parse(response.body.delete_prefix("\uFEFF"), headers: true)
    city_header = Member.human_attribute_name(:city)
    jane_row = csv.find { |row| row[Member.human_attribute_name(:name)] == members(:jane).name }

    assert_includes csv.headers, city_header
    assert_equal "Lausanne", jane_row[city_header]
  end

  test "edit activity fields blank the default and keep overrides" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    assert_select "#membership_activity_participations_demanded_annually[value='2']"
    assert_select "#membership_activity_participations_demanded_annually[placeholder='3']"
    assert_select ".activity-participations-formula"
    assert_select "label[for=membership_activity_participations_demanded_annually]", text: "Demanded count (full year)"
    assert_select "#membership_activity_participations_demanded_annually_input .inline-hints", text: /final demanded count/
    assert_select "#membership_activity_participations_demanded_annually_input .inline-hints a[href='#{edit_organization_path(:activity, anchor: "activity_participations_demanded_logic")}']"
    assert_select ".activity-participations-formula-arrow", count: 1
    assert_select ".activity-participations-demanded.tooltip-wrap"
    assert_select "#membership_activity_participations_demanded[disabled][value='2']"
    assert_select "#tooltip-membership_activity_participations_demanded", text: /Final demanded count/
    assert_select ".activity-participations-formula-logic", count: 0
    assert_select "#membership_activity_participations_annual_price_change[value='0.0']"
    assert_select "#membership_activity_participations_annual_price_change[placeholder='50']"
    assert_select "#membership_activity_participations_annual_price_change_input .inline-hints", text: /Enter 0 to disable/
    assert_select "turbo-frame#membership-activity-participations [data-default-annually='3'][data-demanded='2'][data-default-price-change='50']"
  end

  test "edit keeps annually 0 as an override" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    membership.update!(activity_participations_demanded_annually: 0)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    assert_select "#membership_activity_participations_demanded_annually[value='0']"
    assert_select "#membership_activity_participations_demanded_annually[placeholder='3']"
  end

  test "edit activity fields stay blank when they match the default" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    membership.update!(activity_participations_demanded_annually: 3)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    annually = css_select("#membership_activity_participations_demanded_annually").first
    assert_equal "", annually["value"].to_s
    assert_equal "3", annually["placeholder"]
    price = css_select("#membership_activity_participations_annual_price_change").first
    assert_equal "", price["value"].to_s
    assert_equal "0", price["placeholder"]
    assert_select "#membership_activity_participations_demanded[disabled][value='3']"
  end

  test "new membership leaves annually blank when basket sizes disagree" do
    travel_to "2024-05-01"
    login admins(:super)

    get new_membership_path

    assert_response :success
    annually = css_select("#membership_activity_participations_demanded_annually").first
    assert annually
    assert_equal "", annually["value"].to_s
    assert_equal "", annually["placeholder"].to_s
    assert_select "#membership_activity_participations_demanded[disabled]"
    price = css_select("#membership_activity_participations_annual_price_change").first
    assert_equal "", price["value"].to_s
    assert_equal "", price["placeholder"].to_s
    assert_select "#membership_activity_participations_annual_price_change_input .inline-hints", text: /Enter 0 to disable/
  end

  test "new membership fills annually placeholder when basket sizes share the same count" do
    travel_to "2024-05-01"
    basket_sizes(:large).update!(activity_participations_demanded_annually: 2)
    login admins(:super)

    get new_membership_path

    assert_response :success
    annually = css_select("#membership_activity_participations_demanded_annually").first
    assert_equal "", annually["value"].to_s
    assert_equal "2", annually["placeholder"]
  end

  test "activity participations preview returns turbo frame payload" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    login admins(:super)

    get activity_participations_preview_memberships_path, params: {
      membership: {
        member_id: membership.member_id,
        basket_size_id: membership.basket_size_id,
        basket_quantity: 1,
        depot_id: membership.depot_id,
        delivery_cycle_id: membership.delivery_cycle_id,
        started_on: membership.started_on,
        ended_on: membership.ended_on,
        activity_participations_demanded_annually: 5
      }
    }

    assert_response :success
    assert_select "turbo-frame#membership-activity-participations [data-default-annually='3'][data-demanded='5'][data-default-price-change='-100']"
  end

  test "activity participations preview treats empty annually as the default" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    login admins(:super)

    get activity_participations_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        activity_participations_demanded_annually: "")
    }

    assert_response :success
    assert_select "turbo-frame#membership-activity-participations [data-default-annually='3'][data-demanded='3'][data-default-price-change='0']"
  end

  test "activity participations preview treats annually 0 as an override" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    login admins(:super)

    get activity_participations_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        activity_participations_demanded_annually: "0")
    }

    assert_response :success
    assert_select "turbo-frame#membership-activity-participations [data-demanded='0']"
  end

  test "activity participations preview includes complements in the annually default" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    basket_complements(:bread).update!(activity_participations_demanded_annually: 2)
    login admins(:super)

    get activity_participations_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: basket_complements(:bread).id, quantity: 1 }
        })
    }

    assert_response :success
    assert_select "turbo-frame#membership-activity-participations [data-default-annually='5']"
  end

  test "activity participations preview ignores destroyed complements" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    basket_complements(:bread).update!(activity_participations_demanded_annually: 2)
    login admins(:super)

    get activity_participations_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        memberships_basket_complements_attributes: {
          "0" => {
            basket_complement_id: basket_complements(:bread).id,
            quantity: 1,
            _destroy: "1"
          }
        })
    }

    assert_response :success
    assert_select "turbo-frame#membership-activity-participations [data-default-annually='3']"
  end

  test "show explains when recurring billing is disabled" do
    travel_to "2024-05-01"
    org(recurring_billing_wday: nil)
    login admins(:super)

    get membership_path(memberships(:jane))

    assert_response :success
    assert_select ".muted-data", text: /Recurring billing is disabled/
    assert_select ".muted-data a[href='#{edit_organization_path(:billing)}']", text: "settings"
  end

  test "show explains waiting for the last trial delivery" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update_baskets_counts!
    login admins(:super)

    get membership_path(membership)

    assert_response :success
    assert membership.reload.trial?
    assert_select "td", text: /Waiting for the last trial delivery \(Mon 22 Apr 24\)/
  end

  test "show explains waiting for the last trial delivery when billing day is the last trial day" do
    travel_to "2024-01-01"
    org(billing_starts_after_first_delivery: true, recurring_billing_wday: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!
    login admins(:super)

    get membership_path(membership)

    assert_response :success
    assert membership.reload.trial?
    assert_select "td", text: /Waiting for the last trial delivery \(Thu 11 Apr 24\)/
  end

  test "show displays stop action and icon-only destroy action with confirmations" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    login admins(:super)

    get membership_path(membership)

    assert_response :success
    assert_select "form[action='#{stop_membership_path(membership)}'] button[data-confirm='#{I18n.t("active_admin.resource.show.stop_confirm")}']", text: /Stop/

    destroy_buttons = css_select("form[action='#{membership_path(membership)}'] button.destructive-icon-action[title='#{I18n.t("active_admin.delete_model")}'][aria-label='#{I18n.t("active_admin.delete_model")}'][data-confirm='#{I18n.t("active_admin.resources.membership.delete_confirmation")}']")
    assert_equal 1, destroy_buttons.size
    assert_equal "", destroy_buttons.first.text.squish
  end

  test "show hides stop and destroy actions for renewed membership" do
    travel_to "2024-05-01"
    membership = memberships(:john)
    login admins(:super)

    get membership_path(membership)

    assert_response :success
    assert_select "form[action='#{stop_membership_path(membership)}']", false
    assert_select "form[action='#{membership_path(membership)}'] button[title='#{I18n.t("active_admin.delete_model")}']", false
  end

  test "show hides stop action when stopping today would leave no delivery" do
    travel_to "2024-05-01"
    membership = create_membership(
      member: create_member,
      started_on: "2024-04-30",
      ended_on: "2024-12-31")
    login admins(:super)

    get membership_path(membership)

    assert_response :success
    assert_not membership.can_stop?
    assert_select "form[action='#{stop_membership_path(membership)}']", false
  end

  test "stop ends membership today" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    login admins(:super)

    assert_changes -> { membership.reload.ended_on }, to: Date.current do
      post stop_membership_path(membership)
    end

    assert_redirected_to membership_path(membership)
    assert_equal I18n.t("active_admin.flash.membership_stop_notice"), flash[:notice]
  end

  test "new form points included absences hint at absence settings" do
    travel_to "2024-01-01"
    login admins(:super)

    get new_membership_path

    assert_response :success
    assert_includes response.body, "/settings#absence"
    assert_not_includes response.body, "href='/delivery_cycles'"
  end

  private

  def preview_membership_params(membership)
    {
      member_id: membership.member_id,
      basket_size_id: membership.basket_size_id,
      basket_quantity: 1,
      depot_id: membership.depot_id,
      delivery_cycle_id: membership.delivery_cycle_id,
      started_on: membership.started_on,
      ended_on: membership.ended_on
    }
  end
end
