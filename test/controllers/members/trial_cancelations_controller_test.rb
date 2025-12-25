# frozen_string_literal: true

require "test_helper"

class Members::TrialCancelationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    org(trial_baskets_count: 4)
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "new displays trial cancelation form when can cancel trial" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    get new_members_trial_cancelation_path

    assert_response :success
    assert_select "h2", I18n.t("members.trial_cancelations.new.title")
    assert_select "form[action='#{members_trial_cancelation_path}']"
  end

  test "new redirects when cannot cancel trial" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0)
    member = members(:jane)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    get new_members_trial_cancelation_path

    assert_redirected_to members_memberships_path
  end

  test "new requires authentication" do
    get new_members_trial_cancelation_path

    assert_redirected_to members_login_path
  end

  test "create cancels trial membership" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    post members_trial_cancelation_path, params: {
      membership: { renewal_note: "Not the right fit for our family" }
    }

    assert_redirected_to members_memberships_path
    assert_equal I18n.t("members.trial_cancelations.create.flash.notice"), flash[:notice]

    membership.reload
    assert membership.canceled?
    assert_equal "Not the right fit for our family", membership.renewal_note
  end

  test "create cancels trial membership without note" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    post members_trial_cancelation_path, params: {
      membership: { renewal_note: "" }
    }

    assert_redirected_to members_memberships_path
    assert_equal I18n.t("members.trial_cancelations.create.flash.notice"), flash[:notice]

    membership.reload
    assert membership.canceled?
  end

  test "create requires authentication" do
    post members_trial_cancelation_path, params: {
      membership: { renewal_note: "Testing" }
    }

    assert_redirected_to members_login_path
  end

  test "create redirects when cannot cancel trial" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0)
    member = members(:jane)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    post members_trial_cancelation_path, params: {
      membership: { renewal_note: "Should not work" }
    }

    assert_redirected_to members_memberships_path
    membership.reload
    assert_not membership.canceled?
  end

  test "create sets ended_on to last trial basket date" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    last_trial_basket = membership.baskets.trial.order("deliveries.date").last
    expected_ended_on = last_trial_basket.delivery.date

    post members_trial_cancelation_path, params: {
      membership: { renewal_note: "" }
    }

    membership.reload
    assert_equal expected_ended_on, membership.ended_on
  end

  test "create saves renewal_annual_fee when checked" do
    travel_to "2024-01-01"
    org(annual_fee: 30)
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    post members_trial_cancelation_path, params: {
      membership: { renewal_note: "", renewal_annual_fee: "1" }
    }

    assert_redirected_to members_memberships_path
    membership.reload
    assert membership.canceled?
    assert_equal 30, membership.renewal_annual_fee
  end
end
