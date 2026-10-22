# frozen_string_literal: true

require "test_helper"

class Members::BasketShiftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    travel_to "2024-01-01"
    org(
      features: [ :absence ],
      absences_billed: true,
      basket_shifts_annually: 1,
      basket_shift_deadline_in_weeks: nil)
    login(members(:jane))
  end

  test "new redirects when basket cannot be shifted" do
    basket = baskets(:jane_6)
    org(basket_shifts_annually: 0)

    get new_members_basket_basket_shifts_path(basket)

    assert_redirected_to members_deliveries_path
    assert_equal I18n.t("members.basket_shifts.flash.alert"), flash[:alert]
  end

  test "create cannot decline shift for ineligible basket" do
    basket = baskets(:jane_6)
    org(basket_shifts_annually: 0)

    assert_no_changes -> { basket.reload.shift_declined_at } do
      post members_basket_basket_shifts_path(basket), params: {
        basket: { shift_target_basket_id: "declined" }
      }
    end

    assert_redirected_to members_deliveries_path
    assert_equal I18n.t("members.basket_shifts.flash.alert"), flash[:alert]
  end

  test "new lists member shiftable targets" do
    basket = baskets(:jane_6)
    create_absence(member: basket.member, started_on: basket.delivery.date, ended_on: basket.delivery.date)
    travel_to basket.delivery.date - 1.week

    get new_members_basket_basket_shifts_path(basket)

    assert_response :success
    assert_select "select#basket_shift_target_basket_id option[value='#{baskets(:jane_7).id}']"
    assert_select "select#basket_shift_target_basket_id option[value='declined']"
  end

  test "new lists an existing absence's targets in date order with earlier off-cycle first" do
    basket = baskets(:jane_6)
    later = baskets(:jane_7)
    create_absence(member: basket.member, started_on: basket.delivery.date, ended_on: basket.delivery.date)
    travel_to basket.delivery.date - 1.week
    earlier = Delivery.find_by!(date: later.delivery.date - 3.days)

    get new_members_basket_basket_shifts_path(basket)

    assert_response :success
    assert_select "select#basket_shift_target_basket_id > option[value=declined]"
    assert_select "select#basket_shift_target_basket_id optgroup",
      label: I18n.t("members.basket_shifts.new.after_absence")
    assert_select "select#basket_shift_target_basket_id option[value=?]", "delivery:#{earlier.id}"
    assert_select "select#basket_shift_target_basket_id option[value=?]", later.id

    values = css_select("select#basket_shift_target_basket_id option").map { |option| option["value"] }
    after_group = css_select("select#basket_shift_target_basket_id optgroup").find { |group|
      group["label"] == I18n.t("members.basket_shifts.new.after_absence")
    }
    after = css_select(after_group, "option")
    dates = after.map { |option| shift_target_option_date(option["value"]) }

    assert_equal "declined", values.first
    assert shift_target_option_date(after.first["value"]) < later.delivery.date
    assert dates.index(earlier.date) < dates.index(later.delivery.date)
    assert_equal dates, dates.sort
    assert_select "select#basket_shift_target_basket_id option[value=?]",
      "delivery:#{earlier.id}",
      text: / \*\z/
    assert_select "p.form-hint", text: I18n.t("members.basket_shifts.new.off_cycle_date")
  end

  test "new uses the organization basket name in the off-cycle note" do
    basket = baskets(:jane_6)
    create_absence(member: basket.member, started_on: basket.delivery.date, ended_on: basket.delivery.date)
    travel_to basket.delivery.date - 1.week
    Current.org.update!(basket_i18n_scopes: Current.org.languages.index_with { "bag" })

    get new_members_basket_basket_shifts_path(basket)

    assert_response :success
    assert_select "p.form-hint", text: I18n.t("members.basket_shifts.new.off_cycle_date")
    assert_select "p.form-hint", text: /bag/
  end

  test "new omits the off-cycle note when the depot serves only the cycle" do
    basket = baskets(:jane_6)
    create_absence(member: basket.member, started_on: basket.delivery.date, ended_on: basket.delivery.date)
    travel_to basket.delivery.date - 1.week
    basket.depot.delivery_cycles.clear
    basket.depot.delivery_cycles << basket.membership.delivery_cycle

    get new_members_basket_basket_shifts_path(basket)

    assert_response :success
    assert_select "select#basket_shift_target_basket_id option[value=?]", baskets(:jane_7).id
    assert_select "select#basket_shift_target_basket_id option", text: / \*\z/, count: 0
    assert_select "p.form-hint", count: 0
  end

  test "create shifts to an allowed target" do
    basket = baskets(:jane_6)
    target = baskets(:jane_7)
    create_absence(member: basket.member, started_on: basket.delivery.date, ended_on: basket.delivery.date)
    travel_to basket.delivery.date - 1.week

    assert_changes -> { basket.reload.shifted? }, from: false, to: true do
      post members_basket_basket_shifts_path(basket), params: {
        basket: { shift_target_basket_id: target.id }
      }
    end

    assert_redirected_to members_deliveries_path
    assert_equal I18n.t("members.basket_shifts.flash.notice"), flash[:notice]
    assert_equal target.id, basket.reload.shift_target_basket_id
  end

  test "create declines a shift" do
    basket = baskets(:jane_6)
    create_absence(member: basket.member, started_on: basket.delivery.date, ended_on: basket.delivery.date)
    travel_to basket.delivery.date - 1.week

    assert_changes -> { basket.reload.shift_declined_at }, from: nil do
      post members_basket_basket_shifts_path(basket), params: {
        basket: { shift_target_basket_id: "declined" }
      }
    end

    assert_redirected_to members_deliveries_path
    assert_equal "declined", basket.reload.shift_target_basket_id
  end

  test "new offers an off-cycle date without an absence" do
    basket = memberships(:jane).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)

    get new_members_basket_basket_shifts_path(basket)

    assert_response :success
    assert_select "select#basket_shift_target_basket_id option[value='delivery:#{monday.id}']"
    assert_select "select#basket_shift_target_basket_id option[value='declined']"
  end

  test "create shifts onto an off-cycle date and creates the one-day absence" do
    basket = memberships(:jane).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)

    assert_difference -> { basket.membership.basket_shifts.count }, 1 do
      post members_basket_basket_shifts_path(basket), params: {
        basket: { shift_target_basket_id: "delivery:#{monday.id}" }
      }
    end

    target = basket.membership.baskets.find_by!(delivery: monday)
    assert_redirected_to members_deliveries_path
    assert basket.reload.absent?
    assert_equal basket.membership.basket_quantity, target.quantity
    assert_equal 0, target.baskets_basket_complements.sum(:quantity)
    assert_equal monday.id, basket.shift_as_source.target_delivery_id
  end

  test "create ignores an off-cycle delivery outside the deadline" do
    org(basket_shift_deadline_in_weeks: 1)
    basket = memberships(:jane).baskets.where(state: "normal").first
    travel_to basket.delivery.date - 1.week
    later = Delivery.find_by!(date: basket.delivery.date + 14.days)

    assert_no_difference -> { BasketShift.count } do
      post members_basket_basket_shifts_path(basket), params: {
        basket: { shift_target_basket_id: "delivery:#{later.id}" }
      }
    end

    assert_not basket.reload.absent?
  end

  test "create ignores a target that is not member-shiftable" do
    basket = baskets(:jane_6)
    create_absence(member: basket.member, started_on: basket.delivery.date, ended_on: basket.delivery.date)
    travel_to basket.delivery.date - 1.week

    assert_no_changes -> { basket.reload.shift_as_source } do
      post members_basket_basket_shifts_path(basket), params: {
        basket: { shift_target_basket_id: baskets(:john_7).id }
      }
    end

    assert_redirected_to members_deliveries_path
  end

  private

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  def shift_target_option_date(value)
    if value.start_with?("delivery:")
      Delivery.find(value.delete_prefix("delivery:")).date
    else
      Basket.find(value).delivery.date
    end
  end
end
