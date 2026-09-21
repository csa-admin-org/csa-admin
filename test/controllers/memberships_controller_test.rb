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

  test "edit blanks catalog prices that match the default" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    size_price = css_select("#membership_basket_size_price").first
    assert_equal "", size_price["value"].to_s
    assert_equal "30", size_price["placeholder"]
    depot_price = css_select("#membership_depot_price").first
    assert_equal "", depot_price["value"].to_s
    assert_equal "4", depot_price["placeholder"]
    assert_select "#membership_basket_size_id option[value='#{membership.basket_size_id}'][data-price='30']"
    assert_select "#membership_depot_id option[value='#{membership.depot_id}'][data-price='4']"
    assert_select "#membership_depot_price_input .inline-hints", text: /Leave blank for the default price/
  end

  test "edit keeps a catalog price override including 0" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    membership.update!(basket_size_price: 32, depot_price: 0)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    size_price = css_select("#membership_basket_size_price").first
    assert_equal "32.0", size_price["value"]
    assert_equal "30", size_price["placeholder"]
    depot_price = css_select("#membership_depot_price").first
    assert_equal "0.0", depot_price["value"]
    assert_equal "4", depot_price["placeholder"]
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
    hints = css_select("#membership_absences_included_annually_input .inline-hints").first
    assert_select hints, "a[href='#{edit_organization_path(:absence, anchor: "absences_included_logic")}']"
    assert_select hints, "a[href='#{handbook_page_path(:absence, anchor: "absence-included")}']"
    assert_select ".handbook-button a[href='#{handbook_page_path(:absence, anchor: "absence-included")}']", false
    assert_not_includes response.body, "href='/delivery_cycles'"
  end

  test "edit blanks included absences annually when it matches the cycle default" do
    travel_to "2024-05-01"
    cycle = delivery_cycles(:thursdays)
    cycle.update!(absences_included_annually: 4)
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 4)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    annually = css_select("#membership_absences_included_annually").first
    assert_equal "", annually["value"].to_s
    assert_equal "4", annually["placeholder"]
    assert_select ".admin-formula"
    assert_select "#membership_absences_included[disabled][value='4']"
    assert_select "#tooltip-membership_absences_included", text: /Final included absences/
    assert_select "turbo-frame#membership-absences-included [data-default-annually='4'][data-included='4']"
    assert_select "#membership_delivery_cycle_id option[value='#{cycle.id}'][data-absences-included-annually='4']"
  end

  test "edit keeps included absences annually override including 0" do
    travel_to "2024-05-01"
    delivery_cycles(:thursdays).update!(absences_included_annually: 4)
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 0)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    annually = css_select("#membership_absences_included_annually").first
    assert_equal "0", annually["value"]
    assert_equal "4", annually["placeholder"]
    assert_select "#membership_absences_included[disabled][value='0']"
  end

  test "edit keeps a non-zero included absences annually override" do
    travel_to "2024-05-01"
    delivery_cycles(:thursdays).update!(absences_included_annually: 4)
    membership = memberships(:jane)
    membership.update!(absences_included_annually: 5)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    annually = css_select("#membership_absences_included_annually").first
    assert_equal "5", annually["value"]
    assert_equal "4", annually["placeholder"]
    assert_select "#membership_absences_included[disabled][value='5']"
  end

  test "absences included preview returns turbo frame payload" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    delivery_cycles(:thursdays).update!(absences_included_annually: 4)
    login admins(:super)

    get absences_included_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        absences_included_annually: 5)
    }

    assert_response :success
    assert_select "turbo-frame#membership-absences-included [data-default-annually='4'][data-included='5']"
  end

  test "absences included preview treats empty annually as the cycle default" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    delivery_cycles(:thursdays).update!(absences_included_annually: 4)
    login admins(:super)

    get absences_included_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        absences_included_annually: "")
    }

    assert_response :success
    assert_select "turbo-frame#membership-absences-included [data-default-annually='4'][data-included='4']"
  end

  test "absences included preview treats annually 0 as an override" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    delivery_cycles(:thursdays).update!(absences_included_annually: 4)
    login admins(:super)

    get absences_included_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        absences_included_annually: "0")
    }

    assert_response :success
    assert_select "turbo-frame#membership-absences-included [data-included='0']"
  end

  test "absences included preview uses the selected cycle default" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    delivery_cycles(:thursdays).update!(absences_included_annually: 4)
    delivery_cycles(:mondays).update!(absences_included_annually: 2)
    login admins(:super)

    get absences_included_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        delivery_cycle_id: delivery_cycles(:mondays).id,
        absences_included_annually: "")
    }

    assert_response :success
    assert_select "turbo-frame#membership-absences-included [data-default-annually='2'][data-included='2']"
  end

  test "absences included preview uses deliveries in the form period" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    delivery_cycles(:thursdays).update!(absences_included_annually: 4)
    login admins(:super)

    get absences_included_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        started_on: "2024-01-01",
        ended_on: deliveries(:thursday_5).date.to_s,
        absences_included_annually: "4")
    }

    assert_response :success
    assert_select "turbo-frame#membership-absences-included [data-included='2']"
  end

  test "edit shows billed extra formula when dynamic pricing is on" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: "{{ extra | times: 2 }}")
    membership = memberships(:jane)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    extra = css_select("#membership_basket_price_extra").first
    assert extra
    assert_equal "0.0", extra["value"].to_s
    assert_select ".admin-formula"
    assert_select "#membership_calculated_price_extra[disabled][value='#{billed_extra(0)}']"
    assert_select "#membership_basket_price_extra_input .inline-hints a[href='#{edit_organization_path(:basket_price_extra, anchor: "basket_price_extra_dynamic_pricing")}']"
    assert_select "turbo-frame#membership-basket-price-extra [data-billed-extra='#{billed_extra(0)}']"
  end

  test "edit billed extra keeps a free basket size price" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: "{{ extra | times: basket_size_price }}")
    membership = memberships(:jane)
    membership.update!(basket_size_price: 0, basket_price_extra: 2)
    login admins(:super)

    get edit_membership_path(membership)

    assert_response :success
    assert_select "#membership_calculated_price_extra[disabled][value='#{billed_extra(0)}']"
  end

  test "edit has no extra formula when dynamic pricing is off" do
    travel_to "2024-05-01"
    login admins(:super)

    get edit_membership_path(memberships(:jane))

    assert_response :success
    assert_select "#membership_basket_price_extra"
    assert_select "#membership_calculated_price_extra", false
    assert_select "turbo-frame#membership-basket-price-extra", false
  end

  test "basket price extra preview returns billed extra" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: "{{ extra | times: 2 }}")
    membership = memberships(:jane)
    login admins(:super)

    get basket_price_extra_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        basket_price_extra: 2,
        basket_size_price: 30)
    }

    assert_response :success
    assert_select "turbo-frame#membership-basket-price-extra [data-billed-extra='#{billed_extra(4)}']"
  end

  test "basket price extra preview is zero when extra is zero" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: "{{ extra | plus: 99 }}")
    membership = memberships(:jane)
    login admins(:super)

    get basket_price_extra_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        basket_price_extra: 0,
        basket_size_price: 30)
    }

    assert_response :success
    assert_select "turbo-frame#membership-basket-price-extra [data-billed-extra='#{billed_extra(0)}']"
  end

  test "basket price extra preview matches Liquid on string basket_size_id" do
    travel_to "2024-05-01"
    size = basket_sizes(:large)
    org(basket_price_extra_dynamic_pricing: <<-LIQUID)
      {% if basket_size_id == #{size.id} %}
        {{ extra | times: 3 }}
      {% else %}
        0
      {% endif %}
    LIQUID
    membership = memberships(:jane)
    login admins(:super)

    get basket_price_extra_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        basket_price_extra: "2",
        basket_size_id: size.id.to_s,
        basket_size_price: "30")
    }

    assert_response :success
    assert_select "turbo-frame#membership-basket-price-extra [data-billed-extra='#{billed_extra(6)}']"
  end

  test "basket price extra preview uses size and complements from the form" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: <<-LIQUID)
      {% assign price = basket_size_price | plus: complements_price %}
      {{ price | times: extra }}
    LIQUID
    membership = memberships(:jane)
    login admins(:super)

    get basket_price_extra_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        basket_price_extra: 2,
        basket_size_price: "",
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: basket_complements(:bread).id, quantity: 1, price: "" }
        })
    }

    assert_response :success
    assert_select "turbo-frame#membership-basket-price-extra [data-billed-extra='#{billed_extra((30 + 4) * 2)}']"
  end

  test "basket price extra preview ignores destroyed complements" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: "{{ extra | times: complements_price }}")
    membership = memberships(:jane)
    login admins(:super)

    get basket_price_extra_preview_memberships_path, params: {
      membership: preview_membership_params(membership).merge(
        basket_price_extra: 2,
        basket_size_price: 30,
        memberships_basket_complements_attributes: {
          "0" => {
            basket_complement_id: basket_complements(:bread).id,
            quantity: 1,
            price: 4,
            _destroy: "1"
          }
        })
    }

    assert_response :success
    assert_select "turbo-frame#membership-basket-price-extra [data-billed-extra='#{billed_extra(0)}']"
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

  def billed_extra(amount)
    ApplicationController.helpers.cur(amount)
  end
end
