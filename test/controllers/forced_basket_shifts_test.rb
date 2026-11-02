# frozen_string_literal: true

require "test_helper"

class ForcedBasketShiftsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-01-01"
    org(
      features: [ :absence ],
      trial_baskets_count: 0,
      absences_billed: true,
      absences_included_mode: "provisional_delivery",
      basket_shifts_annually: 2,
      basket_shift_deadline_in_weeks: nil)
    @membership = memberships(:john)
    @membership.update!(absences_included_annually: 2)
    travel_to @membership.absences_included_remindable_on
    @membership.send_absences_included_reminder!
    @membership.reload
    @source = @membership.baskets.forced.last
    @target = @membership.baskets.normal.coming.first
  end

  test "admin shifts a forced basket without creating an absence" do
    host! "admin.acme.test"
    login(admins(:super))
    price = @membership.price
    billed_quantity = @membership.baskets.billable.sum(:quantity)
    source_quantity = @source.quantity
    target_quantity = @target.quantity

    get edit_basket_path(@source)

    assert_response :success
    assert_select "select#basket_shift_target_basket_id option[value='#{@target.id}']"
    assert_select "p.description",
      text: I18n.t("active_admin.resource.form.basket_shift_forced")
    assert_no_match(/An absence will be created/, response.body)

    assert_no_difference [ "Absence.count", "ForcedDelivery.count" ] do
      patch basket_path(@source), params: {
        basket: { shift_target_basket_id: @target.id }
      }
    end

    assert_redirected_to membership_path(@membership)
    assert @source.reload.forced?
    assert @source.shifted?
    assert_nil @source.absence_id
    assert_empty @membership.baskets.provisionally_absent
    assert_equal price, @membership.reload.price
    assert_equal billed_quantity, @membership.baskets.billable.sum(:quantity)
    assert_equal 0, @source.quantity
    assert_equal target_quantity + source_quantity, @target.reload.quantity
  end

  test "member shifts a forced basket without creating an absence" do
    host! "members.acme.test"
    login(members(:john))
    price = @membership.price
    source_quantity = @source.quantity
    target_quantity = @target.quantity

    get new_members_basket_basket_shifts_path(@source)

    assert_response :success
    assert_select "select#basket_shift_target_basket_id option[value='#{@target.id}']"
    assert_select "select#basket_shift_target_basket_id option[value=declined]", count: 0
    assert_select "h2", text: I18n.t("members.basket_shifts.new.forced_subtitle")
    assert_no_match(/During your absence/, response.body)

    assert_no_difference [ "Absence.count", "ForcedDelivery.count" ] do
      post members_basket_basket_shifts_path(@source), params: {
        basket: { shift_target_basket_id: @target.id }
      }
    end

    assert_redirected_to members_deliveries_path
    assert @source.reload.forced?
    assert @source.shifted?
    assert_nil @source.absence_id
    assert_empty @membership.baskets.provisionally_absent
    assert_equal price, @membership.reload.price
    assert_equal 0, @source.quantity
    assert_equal target_quantity + source_quantity, @target.reload.quantity

    get members_deliveries_path(all_future_deliveries: 1, all_past_deliveries: 1)

    assert_select "#basket_#{@source.id}.is-shifted .is-forfeited"
    assert_select "#basket_#{@source.id} .basket-badge.is-absent", count: 0
    assert_select "#basket_#{@source.id} a[href='#{edit_members_basket_path(@source)}']", count: 0
  end

  test "member cannot decline a forced shift" do
    host! "members.acme.test"
    login(members(:john))

    assert_no_changes -> { @source.reload.shift_declined_at } do
      post members_basket_basket_shifts_path(@source), params: {
        basket: { shift_target_basket_id: "declined" }
      }
    end

    assert_redirected_to members_deliveries_path
    assert_not @source.shifted?
    assert @source.forced?
  end

  private

  def login(owner)
    session = case owner
    when Admin
      Session.create!(
        admin_email: owner.email,
        remote_addr: "127.0.0.1",
        user_agent: "Test Browser")
    when Member
      Session.create!(
        member: owner,
        email: owner.emails_array.first,
        remote_addr: "127.0.0.1",
        user_agent: "Test Browser")
    end
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end
