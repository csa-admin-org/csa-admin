# frozen_string_literal: true

require "test_helper"

class AdminDestroyActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  test "default destroy action is icon-only and confirmed" do
    travel_to "2024-05-01"
    absence = absences(:jane_thursday_5)
    login admins(:super)

    get absence_path(absence)

    assert_response :success
    assert_icon_only_destroy_button(
      absence_path(absence),
      I18n.t("active_admin.delete_confirmation"))
  end

  test "delivery destroy action explains membership and billing impact" do
    travel_to "2024-05-01"
    delivery = deliveries(:thursday_5)
    login admins(:super)

    get delivery_path(delivery)

    assert_response :success
    assert_icon_only_destroy_button(
      delivery_path(delivery),
      I18n.t("active_admin.resources.delivery.delete_confirmation"))
  end

  test "delivery destroy handles memberships whose delivery cycle becomes empty" do
    travel_to "2024-01-01"
    org(features: [ :absence ], trial_baskets_count: 0, absences_billed: true)
    delivery = Delivery.create!(date: "2024-04-02")
    delivery_cycle = create_delivery_cycle(wdays: [ 2 ], absences_included_annually: 2)
    membership = create_membership(
      member: create_member,
      delivery_cycle: delivery_cycle,
      started_on: "2024-01-01",
      ended_on: "2024-12-31",
      absences_included_annually: 2)
    login admins(:super)

    assert_changes -> { Delivery.exists?(delivery.id) }, from: true, to: false do
      delete delivery_path(delivery)
    end

    assert_redirected_to deliveries_path
    assert_equal 0, membership.reload.absences_included
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  def assert_icon_only_destroy_button(path, confirmation)
    label = I18n.t("active_admin.delete_model")
    buttons = css_select(
      "form[action='#{path}'] button.destructive-icon-action" \
      "[title='#{label}'][aria-label='#{label}']" \
      "[data-confirm='#{confirmation}']")

    assert_equal 1, buttons.size
    assert_equal "", buttons.first.text.squish
  end
end
