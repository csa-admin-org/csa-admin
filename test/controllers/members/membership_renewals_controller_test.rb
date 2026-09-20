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
end
