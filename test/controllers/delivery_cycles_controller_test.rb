# frozen_string_literal: true

require "test_helper"

class DeliveryCyclesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-05-01"
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "edit shows the default form details placeholder" do
    login admins(:super)
    cycle = delivery_cycles(:mondays)

    get edit_delivery_cycle_path(cycle)

    assert_response :success
    assert_select "fieldset[data-controller='form-details-preview']"
    assert_select "input#delivery_cycle_form_detail_en[placeholder]"
  end

  test "form details preview follows live schedule not the cached count" do
    login admins(:super)

    get form_details_preview_delivery_cycles_path, params: {
      delivery_cycle: {
        price: 0,
        absences_included_annually: 0,
        wdays: [ 1, 4 ],
        periods_attributes: {
          "0" => { from_fy_month: 1, to_fy_month: 12, results: "all" }
        }
      }
    }

    assert_response :success
    assert_select "turbo-frame#delivery-cycle-form-details [data-placeholder-en*='20']"
    assert_select "turbo-frame#delivery-cycle-form-details [data-placeholder-en*='10']",
      count: 0
  end

  test "new shows a live deliveries placeholder not zero" do
    login admins(:super)

    get new_delivery_cycle_path

    assert_response :success
    assert_select "input#delivery_cycle_form_detail_en[placeholder*='20']"
  end

  test "edit shows when current or future memberships keep their price" do
    login admins(:super)

    get edit_delivery_cycle_path(delivery_cycles(:mondays))

    assert_response :success
    assert_select ".admin-info-pane", text: /keep their existing price/
  end

  test "edit shows the default invoice name placeholder" do
    login admins(:super)
    cycle = delivery_cycles(:mondays)

    get edit_delivery_cycle_path(cycle)

    assert_response :success
    assert_select "fieldset[data-controller='form-invoice-name']"
    assert_select "input#delivery_cycle_invoice_name_en[placeholder=?]",
      "#{Delivery.model_name.human(count: 2)}: #{cycle.public_name}"
  end

  test "period change that drops a shift asks for confirmation and does not save" do
    login admins(:super)
    cycle = delivery_cycles(:thursdays)
    shift = shift_jane_may!

    assert_no_enqueued_jobs only: DeliveryCycleBasketsUpdaterJob do
      patch delivery_cycle_path(cycle), params: cycle_params(cycle)
    end

    assert_response :unprocessable_entity
    assert_equal "all", cycle.reload.periods.sole.results
    assert BasketShift.exists?(shift.id)
    assert_select ".admin-warning-pane", text: /can remove shifts/
    assert_select ".admin-warning-pane a[href='/handbook/billing#price-change']", text: "Learn more"
    assert_select ".admin-warning-pane a[href='/handbook/absence#basket-shift']", text: "Learn more"
    assert_select ".admin-warning-pane", text: /Learn more in the handbook/, count: 0
    assert_select ".admin-warning-pane", text: /This change removes/, count: 0
    assert_select "#dropped-basket-shifts[role=alert] table.data-table"
    assert_select "#dropped-basket-shifts .admin-warning-pane-icon"
    assert_select "#dropped-basket-shifts", text: /This change removes 1 shift/
    assert_select "#dropped-basket-shifts", text: /one-day absence created with it/
    assert_select "#dropped-basket-shifts td", text: /2 May 24 → 23 May 24/
    assert_select "#dropped-basket-shifts a[href=?]", member_path(members(:jane))
    assert_select "#dropped-basket-shifts a[href=?]", membership_path(memberships(:jane)),
      text: "##{memberships(:jane).id}"
    assert_select "#dropped-basket-shifts a[href=?]", absence_path(absences(:jane_thursday_5)),
      text: "1 May 24 – 7 May 24"
    assert_select "#dropped-basket-shifts a[href=?]", edit_basket_path(baskets(:jane_5)),
      text: "2 May 24"
    assert_select "#dropped-basket-shifts a[href=?]", edit_basket_path(baskets(:jane_8)),
      text: "23 May 24"
    assert_select "#dropped-basket-shifts a[href='/support']", text: "contact me"
    assert_select "#dropped-basket-shifts #delivery_cycle_confirm_dropped_basket_shifts"
  end

  test "confirmed period change saves and drops the shift" do
    login admins(:super)
    cycle = delivery_cycles(:thursdays)
    shift = shift_jane_may!
    absence = shift.absence

    assert_enqueued_jobs 1, only: DeliveryCycleBasketsUpdaterJob do
      patch delivery_cycle_path(cycle), params: cycle_params(cycle, confirm: "1")
    end
    perform_enqueued_jobs

    assert_redirected_to delivery_cycle_path(cycle)
    assert_equal "first_of_each_month", cycle.reload.periods.sole.results
    assert_not BasketShift.exists?(shift.id)
    assert Absence.exists?(absence.id)
    assert_equal 1, baskets(:jane_5).reload.quantity
    assert_not baskets(:jane_5).shifted?
  end

  test "price change does not ask to confirm shifts" do
    login admins(:super)
    cycle = delivery_cycles(:thursdays)
    shift = shift_jane_may!

    assert_no_enqueued_jobs only: DeliveryCycleBasketsUpdaterJob do
      patch delivery_cycle_path(cycle), params: { delivery_cycle: { price: 5 } }
    end

    assert_redirected_to delivery_cycle_path(cycle)
    assert_equal 5, cycle.reload.price
    assert BasketShift.exists?(shift.id)
  end

  private

  def shift_jane_may!
    BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: memberships(:jane),
      source_delivery: baskets(:jane_5).delivery,
      target_delivery: baskets(:jane_8).delivery)
  end

  def cycle_params(cycle, confirm: "0")
    period = cycle.periods.sole
    {
      delivery_cycle: {
        wdays: cycle.wdays,
        confirm_dropped_basket_shifts: confirm,
        periods_attributes: {
          "0" => { id: period.id, _destroy: "1" },
          "1" => { from_fy_month: 1, to_fy_month: 12, results: "first_of_each_month" }
        }
      }
    }
  end
end
