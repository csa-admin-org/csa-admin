# frozen_string_literal: true

require "test_helper"

class Notification::AdminDeliveryListTest < ActiveSupport::TestCase
  setup do
    # Ensure no admin has delivery_list notification by default
    Admin.update_all(notifications: [])
  end

  test "notifies admin the day before a delivery" do
    admins(:ultra).update_column(:notifications, %w[delivery_list])

    travel_to deliveries(:monday_1).date - 1.day

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end

  test "does not notify admin two days before a delivery" do
    admins(:ultra).update_column(:notifications, %w[delivery_list])

    travel_to deliveries(:monday_1).date - 2.days

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end

  test "does not notify admin on the day of a delivery" do
    admins(:ultra).update_column(:notifications, %w[delivery_list])

    travel_to deliveries(:monday_1).date

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end

  test "notifies depot with emails the day before a delivery (default)" do
    depot = depots(:farm)
    depot.update!(emails: "farm@example.com")
    delivery = deliveries(:monday_1)

    travel_to delivery.date - 1.day

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "farm@example.com" ], mail.to
  end

  test "does not notify depot without emails" do
    depot = depots(:farm)
    assert_not depot.emails?

    travel_to deliveries(:monday_1).date - 1.day

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end

  test "notifies depot with notify_days_before_delivery = 2 two days before" do
    depot = depots(:farm)
    depot.update!(emails: "farm@example.com", notify_days_before_delivery: 2)
    delivery = deliveries(:monday_1)

    # Should NOT fire the day before
    travel_to delivery.date - 1.day
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end

    # Should fire two days before
    travel_to delivery.date - 2.days
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end

  test "notifies depot with notify_days_before_delivery = 0 on the day of delivery" do
    depot = depots(:farm)
    depot.update!(emails: "farm@example.com", notify_days_before_delivery: 0)
    delivery = deliveries(:monday_1)

    # Should NOT fire the day before
    travel_to delivery.date - 1.day
    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end

    # Should fire on the day of delivery
    travel_to delivery.date
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end

  test "handles consecutive-day deliveries correctly" do
    monday_delivery = deliveries(:monday_1) # 2024-04-01

    travel_to monday_delivery.date - 2.days # travel before creating to pass date validation
    sunday_delivery = Delivery.create!(date: monday_delivery.date - 1.day) # 2024-03-31

    home_depot = depots(:home)
    home_depot.update!(emails: "home@example.com")

    farm_depot = depots(:farm)
    farm_depot.update!(emails: "farm@example.com")

    # Create a basket linking home depot to sunday delivery
    Basket.create!(
      delivery: sunday_delivery,
      membership: memberships(:john),
      basket_size: basket_sizes(:medium),
      basket_size_price: 20,
      depot: home_depot,
      depot_price: 9,
      delivery_cycle_price: 0)

    # Day before sunday_delivery (Saturday 2024-03-30):
    # - home_depot notified for sunday_delivery
    travel_to sunday_delivery.date - 1.day
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
    assert_equal [ "home@example.com" ], ActionMailer::Base.deliveries.last.to

    ActionMailer::Base.deliveries.clear

    # Day before monday_delivery = day of sunday_delivery (Sunday 2024-03-31):
    # Both farm and home depots should be notified for monday_delivery
    # (farm has john's baskets, home has bob's basket for monday_1)
    travel_to monday_delivery.date - 1.day
    assert_difference -> { ActionMailer::Base.deliveries.size }, 2 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end

  test "different depots with different notify_days_before_delivery for same delivery" do
    delivery = deliveries(:monday_1) # 2024-04-01

    farm_depot = depots(:farm)
    farm_depot.update!(emails: "farm@example.com", notify_days_before_delivery: 1)

    # bakery has anna's basket for monday_1
    bakery_depot = depots(:bakery)
    bakery_depot.update!(emails: "bakery@example.com", notify_days_before_delivery: 2)

    # Two days before: only bakery should receive
    travel_to delivery.date - 2.days
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
    assert_equal [ "bakery@example.com" ], ActionMailer::Base.deliveries.last.to

    ActionMailer::Base.deliveries.clear

    # One day before: only farm should receive
    travel_to delivery.date - 1.day
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
    assert_equal [ "farm@example.com" ], ActionMailer::Base.deliveries.last.to
  end

  test "no notification when there are no deliveries" do
    travel_to Date.new(2024, 12, 25) # Christmas, no delivery

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      Notification::AdminDeliveryList.notify
      perform_enqueued_jobs
    end
  end
end
