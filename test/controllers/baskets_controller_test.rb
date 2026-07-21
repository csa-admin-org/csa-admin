# frozen_string_literal: true

require "test_helper"

class BasketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-01-01"
    host! "admin.acme.test"
    org(features: [ :absence ], trial_baskets_count: 0, absences_billed: true)
    login admins(:super)

    @membership = memberships(:john)
    @membership.update!(absences_included_annually: 1)
    @basket = @membership.baskets.second
    create_absence(
      member: @membership.member,
      started_on: @basket.delivery.date,
      ended_on: @basket.delivery.date + 1.day)
    @basket.reload
  end

  test "membership links to included absent basket edit form" do
    get membership_path(@membership)

    assert_response :success
    assert_select "a[href=?][data-table-row-action='edit']", edit_basket_path(@basket)
  end

  test "edit form only shows shift controls for included absent basket" do
    get edit_basket_path(@basket)

    assert_response :success
    assert_select "select#basket_shift_target_basket_id"
    assert_select "p.description.mt-2.mb-4",
      text: I18n.t("active_admin.resource.form.basket_shift_absences_included_warning")
    assert_select "select#basket_delivery_id", count: 0
    assert_select "select#basket_depot_id", count: 0
    assert_select "select#basket_basket_size_id", count: 0
    assert_select "input#basket_quantity", count: 0
  end

  test "update only permits shift for included absent basket" do
    target = @membership.baskets.last
    source_quantity = @basket.quantity
    target_quantity = target.quantity
    basket_size = @basket.basket_size
    depot = @basket.depot

    patch basket_path(@basket), params: {
      basket: {
        shift_target_basket_id: target.id,
        basket_size_id: basket_sizes(:small).id,
        depot_id: depots(:bakery).id,
        quantity: 7
      }
    }

    assert_redirected_to membership_path(@membership)
    assert_equal target, @basket.reload.shift_as_source.target_basket
    assert_equal basket_size, @basket.basket_size
    assert_equal depot, @basket.depot
    assert_equal 0, @basket.quantity
    assert_equal target_quantity + source_quantity, target.reload.quantity
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
