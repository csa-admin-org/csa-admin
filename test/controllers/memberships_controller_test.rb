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
end
