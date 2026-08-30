# frozen_string_literal: true

require "test_helper"

class CalendarTest < ActiveSupport::TestCase
  test "spans this ISO week and next, Monday first" do
    travel_to "2024-04-01"

    calendar = Calendar.new
    days = calendar.days

    assert_equal 14, days.size
    assert_equal Date.new(2024, 4, 1), days.first.date
    assert_equal Date.new(2024, 4, 14), days.last.date
    weeks = days.each_slice(7).to_a
    assert_equal 2, weeks.size
    assert weeks.all? { |week| week.size == 7 }
    assert weeks.all? { |week| week.first.date.monday? }
  end

  test "keeps past days and marks them" do
    travel_to "2024-04-04"

    monday = day_on(Date.new(2024, 4, 1))

    assert_equal Date.new(2024, 4, 1), monday.date
    assert monday.past?
    assert_not monday.coming?
    assert monday.busy?
    assert monday.show_counts?
    assert_not monday.event?
  end

  test "marks today and empty Tuesday" do
    travel_to "2024-04-01"

    days = Calendar.new.days.index_by(&:date)

    assert days[Date.new(2024, 4, 1)].today?
    assert_not days[Date.new(2024, 4, 2)].busy?
    assert days[Date.new(2024, 4, 4)].busy?
  end

  test "today still counts after midday" do
    travel_to Time.zone.parse("2024-04-01 15:00")

    monday = day_on(Date.new(2024, 4, 1))

    assert monday.today?
    assert monday.coming?
    assert_not monday.past?
  end

  test "counts active basket quantity" do
    travel_to "2024-04-01"
    baskets(:john_1).update_column(:quantity, 2)

    monday = day_on(Date.new(2024, 4, 1))

    assert_equal deliveries(:monday_1), monday.delivery
    assert_equal 4, monday.baskets_count
  end

  test "counts shop orders without carts, including special deliveries" do
    travel_to "2024-04-01"
    create_shop_order(member: members(:jane), delivery: deliveries(:monday_1), state: "pending")
    create_shop_order(member: members(:bob), delivery: deliveries(:monday_1), state: "cart")
    create_shop_order(
      member: members(:anna),
      delivery: shop_special_deliveries(:wednesday),
      state: "pending")

    days = Calendar.new.days.index_by(&:date)

    assert_equal 2, days[Date.new(2024, 4, 1)].shop_orders_count
    assert_equal shop_special_deliveries(:wednesday), days[Date.new(2024, 4, 5)].special_delivery
    assert_equal 1, days[Date.new(2024, 4, 5)].shop_orders_count
  end

  test "ignores shop days when the shop feature is off" do
    travel_to "2024-04-01"
    org(features: Current.org.features - [ :shop ])

    wednesday = day_on(Date.new(2024, 4, 5))

    assert_nil wednesday.special_delivery
    assert_equal 0, wednesday.shop_orders_count
    assert_not wednesday.busy?
  end

  test "does not treat a closed CSA shop as a shop day" do
    travel_to "2024-04-01"
    deliveries(:monday_1).update_column(:shop_open, false)

    monday = day_on(Date.new(2024, 4, 1))

    assert monday.delivery?
    assert_not monday.shop?
  end

  test "sums enrolled participants and ignores rejected ones" do
    travel_to "2024-04-01"
    morning = create_activity(date: Date.new(2024, 4, 3))
    afternoon = create_activity(date: Date.new(2024, 4, 3), start_time: "13:00", end_time: "15:00")
    ActivityParticipation.create!(member: members(:martha), activity: morning, participants_count: 2)
    ActivityParticipation.create!(member: members(:mary), activity: afternoon, participants_count: 1)
    ActivityParticipation.create!(
      member: members(:jane),
      activity: afternoon,
      participants_count: 1,
      state: "rejected")

    wednesday = day_on(Date.new(2024, 4, 3))

    assert wednesday.activity?
    assert_equal 3, wednesday.participants_count
  end

  test "sums fixture sessions on the same day" do
    travel_to "2024-07-01"

    harvest = day_on(Date.new(2024, 7, 1))

    assert_equal 3, harvest.participants_count
    assert_equal 2, harvest.activity_ids.size
  end

  test "ignores activities when the activity feature is off" do
    travel_to "2024-07-01"
    org(features: Current.org.features - [ :activity ])

    harvest = day_on(Date.new(2024, 7, 1))

    assert_not harvest.activity?
    assert_equal 0, harvest.participants_count
  end

  test "present? is true when a coming day is busy" do
    travel_to "2024-04-01"

    assert Calendar.new.present?
  end

  test "present? is false when remaining days are empty" do
    travel_to "2024-08-01"

    assert_not Calendar.new.present?
  end

  test "start_on is the Monday of the given date" do
    travel_to "2024-04-04"

    calendar = Calendar.new

    assert_equal Date.new(2024, 4, 1), calendar.start_on
    assert calendar.default?
    assert_equal Date.new(2024, 3, 25), calendar.prev_start_on
    assert_equal Date.new(2024, 4, 8), calendar.next_start_on
  end

  test "shifts a given Monday by seven days" do
    travel_to "2024-04-01"
    calendar = Calendar.new(Date.new(2024, 4, 8))

    assert_equal Date.new(2024, 4, 8), calendar.start_on
    assert_equal Date.new(2024, 4, 21), calendar.days.last.date
    assert_not calendar.default?
    assert_equal Date.new(2024, 4, 1), calendar.prev_start_on
    assert_equal Date.new(2024, 4, 15), calendar.next_start_on
  end

  test "busy_mondays span first to last busy Monday" do
    mondays = Calendar.busy_mondays

    assert_equal Date.new(2023, 4, 3), mondays.begin
    assert_equal Date.new(2025, 6, 9), mondays.end
  end

  test "disables previous at the first busy Monday" do
    calendar = Calendar.new(Date.new(2023, 4, 3))

    assert_nil calendar.prev_start_on
    assert_equal Date.new(2023, 4, 10), calendar.next_start_on
  end

  test "disables next at the last busy Monday" do
    calendar = Calendar.new(Date.new(2025, 6, 9))

    assert_equal Date.new(2025, 6, 2), calendar.prev_start_on
    assert_nil calendar.next_start_on
  end

  private

  def day_on(date)
    Calendar.new.days.find { |day| day.date == date }
  end
end
