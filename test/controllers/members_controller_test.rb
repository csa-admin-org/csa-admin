# frozen_string_literal: true

require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
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

  def member_mail_delivery_count(action)
    MailDelivery.where(mailable_type: "Member", action: action).count
  end

  test "show hides membership request panel for support-only pending member" do
    member = members(:mary)
    member.update!(
      state: "pending",
      validated_at: nil,
      annual_fee: 30,
      waiting_basket_size_id: 0,
      waiting_depot: nil,
      waiting_delivery_cycle: nil,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: nil)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "tr[data-row='basket_size']", false
  end

  test "show displays membership request panel for pending member with membership request" do
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "p", text: "Validation will place this member on the waiting list."
    assert_select "tr[data-row='basket_size']"
  end

  test "show disables validation when direct membership has no upcoming delivery" do
    travel_to "2026-01-01"
    org(features: Current.org.features - [ :waiting_list ])
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "p.text-red-600", text: "Validation cannot create a membership because the selected delivery cycle has no upcoming delivery."
    assert_select "button[disabled]", text: /Validate/
  end

  test "show displays waiting member activation start date" do
    travel_to "2024-05-01"
    member = members(:aria)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "p", text: "Activation will create a membership starting on 6 May 2024."
    assert_select "button:not([disabled])", text: /Activate/
  end

  test "show disables activation when waiting member has no upcoming delivery" do
    travel_to "2026-01-01"
    member = members(:aria)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "p.text-red-600", text: "Activation cannot create a membership because the selected delivery cycle has no upcoming delivery."
    assert_select "button[disabled]", text: /Activate/
  end

  test "validate with direct membership redirects to created membership" do
    travel_to "2024-05-01"
    org(features: Current.org.features - [ :waiting_list ])
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    login admins(:super)

    assert_difference "Membership.count", 1 do
      post validate_member_path(member)
    end

    membership = member.reload.memberships.order(:id).last
    assert_redirected_to membership_path(membership)
  end

  test "create with direct membership sends activated email only" do
    travel_to "2024-05-01"
    org(features: Current.org.features - [ :waiting_list ])
    mail_templates(:member_validated).update!(active: true)
    mail_templates(:member_activated).update!(active: true)
    login admins(:super)

    assert_difference -> { member_mail_delivery_count("activated") }, 1 do
      assert_no_difference -> { member_mail_delivery_count("validated") } do
        assert_difference "Membership.count", 1 do
          post members_path, params: {
            member: {
              name: "Direct Active",
              emails: "direct-active@example.com",
              phones: "+41 79 123 45 67",
              street: "Nowhere 1",
              zip: "1234",
              city: "City",
              country_code: "CH",
              waiting_membership_started_on: "2024-05-06",
              waiting_basket_size_id: basket_sizes(:small).id,
              waiting_depot_id: depots(:farm).id,
              waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
              waiting_billing_year_division: 1,
              send_validation_email: "1"
            }
          }
        end
      end
    end

    member = Member.find_by!(emails: "direct-active@example.com")
    assert_redirected_to member_path(member)
    assert member.active?
    assert member.validated_at?
  end
end
