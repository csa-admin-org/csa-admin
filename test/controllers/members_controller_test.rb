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

  test "show resend welcome email is hidden for pending members" do
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)
    mail_templates(:member_validated).update!(active: true)
    login admins(:super)

    get member_path(member)

    assert_response :success
    assert_select "form[action='#{resend_welcome_email_member_path(member)}']", false
  end

  test "resend welcome email delivers member activated" do
    travel_to "2024-05-01"
    mail_templates(:member_activated).update!(active: true)
    members(:jane).update_columns(activated_at: Time.current)
    login admins(:super)

    assert_difference -> { member_mail_delivery_count("activated") }, 1 do
      post resend_welcome_email_member_path(members(:jane))
    end

    assert_redirected_to member_path(members(:jane))
  end

  test "resend welcome email delivers member validated for waiting members" do
    mail_templates(:member_validated).update!(active: true)
    members(:aria).update_columns(validated_at: Time.current)
    login admins(:super)

    assert_difference -> { member_mail_delivery_count("validated") }, 1 do
      post resend_welcome_email_member_path(members(:aria))
    end

    assert_redirected_to member_path(members(:aria))
  end

  test "show resend welcome email is hidden after two weeks" do
    travel_to "2024-05-01"
    mail_templates(:member_activated).update!(active: true)
    members(:jane).update_columns(activated_at: 3.weeks.ago)
    login admins(:super)

    get member_path(members(:jane))

    assert_response :success
    assert_select "form[action='#{resend_welcome_email_member_path(members(:jane))}']", false
  end

  test "show resend welcome email is hidden after the member logged in" do
    travel_to "2024-05-01"
    mail_templates(:member_activated).update!(active: true)
    members(:jane).update_columns(activated_at: Time.current)
    Session.create!(
      member: members(:jane),
      email: members(:jane).emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    login admins(:super)

    get member_path(members(:jane))

    assert_response :success
    assert_select "form[action='#{resend_welcome_email_member_path(members(:jane))}']", false
  end

  test "index renders membership scopes, shop mode, and CSV" do
    login admins(:super)

    get members_path
    assert_response :success

    get members_path(scope: :waiting)
    assert_response :success

    org(member_form_mode: "shop")
    get members_path
    assert_response :success

    get members_path(format: :csv)
    assert_response :success
  end

  test "show explains when recurring billing is disabled" do
    member = members(:john)
    org(recurring_billing_wday: nil)
    login admins(:super)

    get member_path(member)

    assert_response :success
    assert_select ".muted-data", text: /Recurring billing is disabled/
    assert_select ".muted-data a[href='#{edit_organization_path(:billing)}']", text: "settings"
  end

  test "show links disabled billing to settings overview for read-only admins" do
    member = members(:john)
    org(recurring_billing_wday: nil)
    login admins(:external)

    get member_path(member)

    assert_response :success
    assert_select ".muted-data a[href='#{organization_path(anchor: :billing)}']"
  end

  test "show marks each compact table row with its resource link" do
    member = members(:john)

    login admins(:super)
    get member_path(member)

    assert_response :success
    rows = css_select("tbody[data-controller='table-row'] tr[data-table-row-target='row']")
    assert_not_empty rows
    rows.each do |row|
      assert_equal 1, row.css("a[data-table-row-action='show']").size
    end
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
    assert_select ".activity-participations-formula-text", text: /0/
  end

  test "new member form renders the activity formula row" do
    travel_to "2024-05-01"
    login admins(:super)

    get new_member_path

    assert_response :success
    annually = css_select("#member_waiting_activity_participations_demanded_annually").first
    assert annually
    assert_equal "", annually["value"].to_s
    assert_equal "", annually["placeholder"].to_s
    assert_select "#member_waiting_activity_participations_demanded[disabled]"
    assert_select "label[for=member_waiting_activity_participations_demanded_annually]", text: "½ Days (Full year)"
    assert_select "#member_waiting_activity_participations_demanded_annually_input .inline-hints a[href='#{edit_organization_path(:activity, anchor: "activity_participations_demanded_logic")}']"
  end

  test "edit waiting member keeps annually 0 as an override" do
    travel_to "2024-05-01"
    login admins(:super)

    get edit_member_path(members(:aria))

    assert_response :success
    assert_select "#member_waiting_activity_participations_demanded_annually[value='0']"
    assert_select "#member_waiting_activity_participations_demanded_annually[placeholder='2']"
    assert_select "#member_waiting_activity_participations_demanded[disabled]"
  end

  test "activity participations preview for waiting members uses the start date period" do
    travel_to "2024-05-01"
    login admins(:super)

    get activity_participations_preview_members_path, params: {
      member: {
        waiting_basket_size_id: basket_sizes(:medium).id,
        waiting_depot_id: depots(:farm).id,
        waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
        waiting_membership_started_on: "2024-05-06",
        waiting_activity_participations_demanded_annually: 4
      }
    }

    assert_response :success
    assert_select "turbo-frame#membership-activity-participations [data-default-annually='2'][data-demanded]"
  end

  test "edit waiting member shows billed extra formula when dynamic pricing is on" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: "{{ extra | times: 2 }}")
    login admins(:super)

    get edit_member_path(members(:aria))

    assert_response :success
    extra = css_select("#member_waiting_basket_price_extra").first
    assert extra
    assert_equal "0.0", extra["value"].to_s
    assert_select "#member_waiting_calculated_price_extra[disabled]"
    assert_select "#member_waiting_basket_price_extra_input .inline-hints a[href='#{edit_organization_path(:basket_price_extra, anchor: "basket_price_extra_dynamic_pricing")}']"
    assert_select "turbo-frame#membership-basket-price-extra"
  end

  test "edit waiting member has no extra formula when dynamic pricing is off" do
    travel_to "2024-05-01"
    login admins(:super)

    get edit_member_path(members(:aria))

    assert_response :success
    assert_select "#member_waiting_basket_price_extra"
    assert_select "#member_waiting_calculated_price_extra", false
    assert_select "turbo-frame#membership-basket-price-extra", false
  end

  test "basket price extra preview for waiting members uses size and complements" do
    travel_to "2024-05-01"
    org(basket_price_extra_dynamic_pricing: <<-LIQUID)
      {% assign price = basket_size_price | plus: complements_price %}
      {{ price | times: extra }}
    LIQUID
    login admins(:super)

    get basket_price_extra_preview_members_path, params: {
      member: {
        waiting_basket_size_id: basket_sizes(:medium).id,
        waiting_basket_price_extra: 2,
        members_basket_complements_attributes: {
          "0" => { basket_complement_id: basket_complements(:bread).id, quantity: 1 }
        }
      }
    }

    assert_response :success
    assert_select "turbo-frame#membership-basket-price-extra [data-billed-extra='#{ApplicationController.helpers.cur((20 + 4) * 2)}']"
  end

  test "show disables validation when direct membership has no upcoming delivery" do
    travel_to "2026-01-01"
    org(features: Current.org.features - [ :waiting_list ])
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "p", text: "Validation cannot create a membership because the selected delivery cycle has no upcoming delivery."
    assert_select "button[disabled]", text: /Validate/
  end

  test "show renders disabled delete action as icon-only" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update_columns(state: "inactive")

    login admins(:super)
    get member_path(member)

    assert_response :success
    delete_label = I18n.t("active_admin.delete_model")
    delete_wrappers = css_select("span[tabindex='0'][title='#{delete_label}'][aria-label='#{delete_label}']")
    delete_buttons = css_select("button[disabled][title='#{delete_label}'][aria-label='#{delete_label}']")

    assert_equal 1, delete_wrappers.size
    assert_equal 1, delete_buttons.size
    assert_equal "", delete_buttons.first.text.squish
  end

  test "show renders become member action as a blank-target post form" do
    member = members(:john)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "form[action='#{become_member_path(member)}'][method='post'][target='_blank'][rel='noopener'][data-turbo='false']" do |forms|
      assert_nil forms.first["data-controller"]
      assert_select "button.action-item-button.action-item-link-button", text: /Account/
    end
  end

  test "become member creates an admin-originated member session" do
    admin = admins(:super)
    member = members(:john)

    login admin

    assert_difference "Session.count" do
      post become_member_path(member)
    end

    session = Session.order(:id).last
    assert_equal admin, session.admin
    assert_equal member, session.member
    assert_redirected_to %r{\Ahttp://members\.acme\.test/sessions/}
  end

  test "become member succeeds when the admin email is outbound suppressed" do
    admin = admins(:super)
    member = members(:john)

    login admin
    suppress_email(admin.email)

    assert_difference "Session.count" do
      post become_member_path(member)
    end

    session = Session.order(:id).last
    assert session.admin_originated?
    assert_equal admin, session.admin
    assert_equal member, session.member
    assert_redirected_to %r{\Ahttp://members\.acme\.test/sessions/}
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

  test "show displays waiting member direct activation start date" do
    travel_to "2024-05-01"
    member = members(:aria)
    member.update!(waiting_membership_started_on: Date.new(2024, 5, 20))

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "p", text: "Activation will create a membership starting on 20 May 2024."
    assert_select "tr[data-row='waiting_membership_started_on']"
    assert_select "button:not([disabled])", text: /Activate/
  end

  test "show disables activation when waiting member has no upcoming delivery" do
    travel_to "2026-01-01"
    member = members(:aria)

    login admins(:super)
    get member_path(member)

    assert_response :success
    assert_select "p", text: "Activation cannot create a membership because the selected delivery cycle has no upcoming delivery."
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

  test "validate uses direct membership start date saved from previous edit" do
    travel_to "2024-05-01"
    mail_templates(:member_validated).update!(active: true)
    mail_templates(:member_activated).update!(active: true)
    member = members(:aria)
    member.update!(state: "pending", validated_at: nil)

    login admins(:super)
    patch member_path(member), params: {
      member: { waiting_membership_started_on: "2024-05-20" }
    }

    assert_redirected_to member_path(member)
    assert_equal Date.new(2024, 5, 20), member.reload.waiting_membership_started_on

    assert_difference -> { member_mail_delivery_count("activated") }, 1 do
      assert_no_difference -> { member_mail_delivery_count("validated") } do
        assert_difference "Membership.count", 1 do
          post validate_member_path(member)
        end
      end
    end

    membership = member.reload.memberships.order(:id).last
    assert_equal Date.new(2024, 5, 20), membership.started_on
    assert_redirected_to membership_path(membership)
  end

  test "edit form salary basket hint mentions complements and custom prices" do
    login admins(:super)

    get edit_member_path(members(:john))

    assert_response :success
    assert_includes response.body, I18n.t("formtastic.hints.member.salary_basket_html")
  end

  test "stale waiting membership start date is hidden and treated as blank" do
    travel_to "2024-05-01"
    member = members(:aria)
    member.update_columns(
      state: "pending",
      validated_at: nil,
      waiting_membership_started_on: Date.new(2024, 4, 29))

    login admins(:super)
    get edit_member_path(member)

    assert_response :success
    assert_select "input[name='member[waiting_membership_started_on]']" do |inputs|
      assert inputs.first["value"].blank?
      assert_equal "2024-05-01", inputs.first["min"]
    end

    assert_no_difference "Membership.count" do
      post validate_member_path(member)
    end

    assert_redirected_to member_path(member)
    assert member.reload.waiting?
    assert_nil member[:waiting_membership_started_on]
  end

  test "activate uses direct membership start date saved on waiting member" do
    travel_to "2024-05-01"
    member = members(:aria)
    member.update!(waiting_membership_started_on: Date.new(2024, 5, 20))

    login admins(:super)

    assert_difference "Membership.count", 1 do
      post create_membership_member_path(member)
    end

    membership = member.reload.memberships.order(:id).last
    assert_equal Date.new(2024, 5, 20), membership.started_on
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
