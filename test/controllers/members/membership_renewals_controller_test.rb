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
end
