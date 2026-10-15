# frozen_string_literal: true

require "test_helper"

class Members::MembershipRenewalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    travel_to "2024-11-01"
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "renew form uses rails-ujs disable_with" do
    memberships(:jane).touch(:renewal_opened_at)
    login(members(:jane))

    get members_renew_membership_path

    assert_response :success
    assert_select "form[action='#{members_membership_renewal_path}'][data-turbo=false][data-controller~=form-pricing]"
    assert_select "form[action='#{members_membership_renewal_path}'] button[type=submit][data-disable-with=?]",
      I18n.t("formtastic.processing")
  end

  test "cancel form uses rails-ujs disable_with" do
    memberships(:jane).touch(:renewal_opened_at)
    login(members(:jane))

    get new_members_membership_renewal_path(decision: "cancel")

    assert_response :success
    assert_select "form[action='#{members_membership_renewal_path}'][data-turbo=false] button[type=submit][data-disable-with=?]",
      I18n.t("formtastic.processing")
  end

  test "GET late opened renewal is allowed before the new FY has past deliveries" do
    memberships(:jane).touch(:renewal_opened_at)
    login(members(:jane))
    travel_to "2025-01-05"
    Current.reset

    get members_renew_membership_path

    assert_response :success
  end

  test "POST late opened renewal creates the next membership before deliveries start" do
    memberships(:jane).touch(:renewal_opened_at)
    login(members(:jane))
    travel_to "2025-01-05"
    Current.reset

    assert_difference -> { Membership.count }, 1 do
      post members_membership_renewal_path, params: {
        membership: { renewal_decision: "renew" }
      }
    end

    assert_redirected_to members_memberships_path
    membership = memberships(:jane).reload
    assert membership.renewed?
    assert_equal "2025-01-01", membership.renewed_membership.started_on.to_s
  end

  test "GET past-year opened renewal redirects after the new FY has past deliveries" do
    memberships(:jane).touch(:renewal_opened_at)
    login(members(:jane))
    travel_to "2025-04-11"
    Current.reset

    get members_renew_membership_path

    assert_redirected_to members_memberships_path
  end

  test "POST past-year opened renewal redirects and creates nothing after deliveries started" do
    memberships(:jane).touch(:renewal_opened_at)
    login(members(:jane))
    travel_to "2025-04-11"
    Current.reset

    assert_no_difference -> { Membership.count } do
      post members_membership_renewal_path, params: {
        membership: { renewal_decision: "renew" }
      }
    end

    assert_redirected_to members_memberships_path
    membership = memberships(:jane).reload
    assert membership.renewal_opened?
    assert_not membership.renewed?
  end

  test "renewal form omits a current cycle with no deliveries in the renewal year and preselects a valid one" do
    empty_cycle = create_delivery_cycle_without_renewal_year_deliveries
    membership = memberships(:jane)
    membership.update!(delivery_cycle: empty_cycle)
    membership.touch(:renewal_opened_at)
    login(members(:jane))

    get members_renew_membership_path

    assert_response :success
    assert_select "input[type=radio][name='membership[delivery_cycle_id]'][value=?]",
      empty_cycle.id, count: 0
    selected = css_select("input[type=radio][name='membership[delivery_cycle_id]'][checked=checked]").first
    assert selected
    selected_id = selected["value"].to_i
    assert_not_equal empty_cycle.id, selected_id
    assert DeliveryCycle.find(selected_id).deliveries_count_for(membership.fy_year + 1).positive?
  end

  test "renewal succeeds when the form preselects a cycle with deliveries in the renewal year" do
    empty_cycle = create_delivery_cycle_without_renewal_year_deliveries
    membership = memberships(:jane)
    membership.update!(delivery_cycle: empty_cycle)
    membership.touch(:renewal_opened_at)
    login(members(:jane))

    get members_renew_membership_path
    selected = css_select("input[type=radio][name='membership[delivery_cycle_id]'][checked=checked]").first
    selected_id = selected["value"]

    assert_difference -> { Membership.count }, 1 do
      post members_membership_renewal_path, params: {
        membership: {
          renewal_decision: "renew",
          delivery_cycle_id: selected_id
        }
      }
    end

    assert_redirected_to members_memberships_path
    membership.reload
    assert membership.renewed?
    assert_equal selected_id.to_i, membership.renewed_membership.delivery_cycle_id
    assert membership.renewed_membership.baskets.any?
  end

  test "GET past-year opened renewal redirects inactive members to re-register after deliveries started" do
    travel_to "2024-01-01"
    membership = create_membership(
      member: members(:mary),
      started_on: "2023-01-01",
      ended_on: "2023-12-31")
    membership.update_columns(renew: true, renewal_opened_at: Time.current)
    travel_to "2024-10-02"
    Current.reset
    login(members(:mary).reload)

    get members_renew_membership_path

    assert_redirected_to new_members_member_path
  end

  private

  def create_delivery_cycle_without_renewal_year_deliveries
    create_delivery_cycle(
      names: { en: "Early Season" },
      wdays: [ 4 ],
      last_cweek: 14,
      depots: Depot.kept.to_a).tap do |cycle|
      assert_operator cycle.deliveries_count_for(Current.fy_year), :positive?
      assert_equal 0, cycle.deliveries_count_for(Current.fy_year + 1)
    end
  end
end
