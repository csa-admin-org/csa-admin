# frozen_string_literal: true

require "test_helper"

class BasketSize::DeliverabilityTest < ActiveSupport::TestCase
  def delivery_on(date)
    Delivery.new(date: date)
  end

  test "always_deliverable? returns true when no cweek limits are set" do
    basket_size = basket_sizes(:small)

    assert_nil basket_size.first_cweek
    assert_nil basket_size.last_cweek
    assert basket_size.always_deliverable?
  end

  test "always_deliverable? returns false when cweek limits are set" do
    basket_size = basket_sizes(:small)

    basket_size.update!(first_cweek: 10)
    assert_not basket_size.always_deliverable?

    basket_size.update!(first_cweek: nil, last_cweek: 45)
    assert_not basket_size.always_deliverable?

    basket_size.update!(first_cweek: 10, last_cweek: 45)
    assert_not basket_size.always_deliverable?
  end

  test "delivered_on? returns true when no cweek limits are set" do
    basket_size = basket_sizes(:small)

    assert basket_size.always_deliverable?
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 1, 15)))
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 6, 15)))
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 12, 31)))
  end

  test "delivered_on? with only first_cweek set" do
    basket_size = basket_sizes(:small)
    basket_size.update!(first_cweek: 11)

    # Week 10 (early March 2024) - before first_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2024, 3, 4)))

    # Week 11 (mid March 2024) - at first_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 3, 11)))

    # Week 12 (late March 2024) - after first_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 3, 18)))

    # Week 52 (end of year) - after first_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 12, 23)))
  end

  test "delivered_on? with only last_cweek set" do
    basket_size = basket_sizes(:small)
    basket_size.update!(last_cweek: 45)

    # Week 1 (early January 2024) - before last_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 1, 1)))

    # Week 45 (early November 2024) - at last_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 4)))

    # Week 46 (mid November 2024) - after last_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 11)))

    # Week 52 (end of year) - after last_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2024, 12, 23)))
  end

  test "delivered_on? with first_cweek and last_cweek range" do
    basket_size = basket_sizes(:small)
    basket_size.update!(first_cweek: 11, last_cweek: 45)

    # Week 10 - before range
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2024, 3, 4)))

    # Week 11 - start of range
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 3, 11)))

    # Week 25 - middle of range
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 6, 17)))

    # Week 45 - end of range
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 4)))

    # Week 46 - after range
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 11)))
  end

  test "delivered_on? with cross-year fiscal year and first_cweek" do
    # Fiscal year from April 2024 to March 2025
    org(fiscal_year_start_month: 4)
    basket_size = basket_sizes(:small)
    basket_size.update!(first_cweek: 47)

    # Week 45 (Nov 2024) - before first_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 4)))

    # Week 47 (Nov 2024) - at first_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 18)))

    # Week 48 (Nov 2024) - after first_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 25)))

    # Week 2 (Jan 2025) - after first_cweek (new calendar year, same fiscal year)
    assert basket_size.delivered_on?(delivery_on(Date.new(2025, 1, 6)))

    # Week 10 (Mar 2025) - after first_cweek (end of fiscal year)
    assert basket_size.delivered_on?(delivery_on(Date.new(2025, 3, 3)))
  end

  test "delivered_on? with cross-year fiscal year and last_cweek" do
    # Fiscal year from April 2024 to March 2025
    org(fiscal_year_start_month: 4)
    basket_size = basket_sizes(:small)
    basket_size.update!(last_cweek: 3)

    # Week 45 (Nov 2024) - before last_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 4)))

    # Week 48 (Nov 2024) - before last_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 25)))

    # Week 2 (Jan 2025) - before last_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2025, 1, 6)))

    # Week 3 (Jan 2025) - at last_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2025, 1, 13)))

    # Week 4 (Jan 2025) - after last_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2025, 1, 20)))

    # Week 10 (Mar 2025) - after last_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2025, 3, 3)))
  end

  test "delivered_on? with cross-year fiscal year and first_cweek and last_cweek" do
    # Fiscal year from April 2024 to March 2025
    org(fiscal_year_start_month: 4)
    basket_size = basket_sizes(:small)
    basket_size.update!(first_cweek: 46, last_cweek: 3)

    # Week 45 (Nov 2024) - before first_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 4)))

    # Week 46 (Nov 2024) - at first_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 11)))

    # Week 48 (Nov 2024) - in range
    assert basket_size.delivered_on?(delivery_on(Date.new(2024, 11, 25)))

    # Week 2 (Jan 2025) - in range
    assert basket_size.delivered_on?(delivery_on(Date.new(2025, 1, 6)))

    # Week 3 (Jan 2025) - at last_cweek
    assert basket_size.delivered_on?(delivery_on(Date.new(2025, 1, 13)))

    # Week 4 (Jan 2025) - after last_cweek
    assert_not basket_size.delivered_on?(delivery_on(Date.new(2025, 1, 20)))
  end

  test "first_cweek validation" do
    basket_size = basket_sizes(:small)

    basket_size.first_cweek = 0
    assert_not basket_size.valid?
    assert_includes basket_size.errors[:first_cweek], "must be greater than or equal to 1"

    basket_size.first_cweek = 54
    assert_not basket_size.valid?
    assert_includes basket_size.errors[:first_cweek], "must be less than or equal to 53"

    basket_size.first_cweek = 1
    assert basket_size.valid?

    basket_size.first_cweek = 53
    assert basket_size.valid?

    basket_size.first_cweek = nil
    assert basket_size.valid?
  end

  test "last_cweek validation" do
    basket_size = basket_sizes(:small)

    basket_size.last_cweek = 0
    assert_not basket_size.valid?
    assert_includes basket_size.errors[:last_cweek], "must be greater than or equal to 1"

    basket_size.last_cweek = 54
    assert_not basket_size.valid?
    assert_includes basket_size.errors[:last_cweek], "must be less than or equal to 53"

    basket_size.last_cweek = 1
    assert basket_size.valid?

    basket_size.last_cweek = 53
    assert basket_size.valid?

    basket_size.last_cweek = nil
    assert basket_size.valid?
  end

  test "filter_deliveries returns all deliveries when no cweek limits" do
    basket_size = basket_sizes(:small)
    deliveries = [
      Delivery.new(date: Date.new(2024, 1, 15)),
      Delivery.new(date: Date.new(2024, 6, 15)),
      Delivery.new(date: Date.new(2024, 12, 31))
    ]

    assert_nil basket_size.first_cweek
    assert_nil basket_size.last_cweek
    assert_equal deliveries, basket_size.filter_deliveries(deliveries)
  end

  test "filter_deliveries filters by cweek range" do
    basket_size = basket_sizes(:small)
    # Week 11 is around March 11, week 45 is around November 4
    basket_size.update!(first_cweek: 11, last_cweek: 45)

    deliveries = [
      Delivery.new(date: Date.new(2024, 3, 4)),   # Week 10 - outside
      Delivery.new(date: Date.new(2024, 3, 11)),  # Week 11 - inside
      Delivery.new(date: Date.new(2024, 6, 17)),  # Week 25 - inside
      Delivery.new(date: Date.new(2024, 11, 4)),  # Week 45 - inside
      Delivery.new(date: Date.new(2024, 11, 11))  # Week 46 - outside
    ]

    filtered = basket_size.filter_deliveries(deliveries)

    assert_equal 3, filtered.size
    assert_equal [ Date.new(2024, 3, 11), Date.new(2024, 6, 17), Date.new(2024, 11, 4) ],
      filtered.map(&:date)
  end

  test "billable_deliveries_counts returns default when no cweek limits" do
    basket_size = basket_sizes(:small)

    assert basket_size.always_deliverable?
    assert_equal DeliveryCycle.billable_deliveries_counts, basket_size.billable_deliveries_counts
  end

  test "billable_deliveries_counts filters by cweek range" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)

    # Default: 10 deliveries per day (future year), 20 total for all cycle
    assert_equal [ 10, 20 ], basket_size.billable_deliveries_counts

    # Restrict to cweek 20+ (future year deliveries are weeks 15-24)
    # Weeks 20-24 = 5 deliveries per day
    basket_size.update!(first_cweek: 20)

    assert_equal [ 5, 10 ], basket_size.billable_deliveries_counts
  end
end
