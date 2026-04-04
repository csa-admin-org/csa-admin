# frozen_string_literal: true

require "test_helper"

class Notification::BasketComplementWeeklySummaryTest < ActiveSupport::TestCase
  test "sends weekly summary for complements with emails and deliveries" do
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com", language: "en")

    # Sunday before the week containing thursday_1 (2024-04-04)
    travel_to Date.new(2024, 3, 31) do
      assert_difference -> { BasketComplementMailer.deliveries.size }, 1 do
        Notification::BasketComplementWeeklySummary.notify
        perform_enqueued_jobs
      end

      mail = BasketComplementMailer.deliveries.last
      assert_equal [ "bread-supplier@example.com" ], mail.to
      assert_includes mail.subject, "Bread"
    end
  end

  test "does not send when complement has no emails" do
    travel_to Date.new(2024, 3, 31) do
      assert_no_difference -> { BasketComplementMailer.deliveries.size } do
        Notification::BasketComplementWeeklySummary.notify
        perform_enqueued_jobs
      end
    end
  end

  test "does not send when no deliveries in the coming week" do
    bread = basket_complements(:bread)
    bread.update!(emails: "bread-supplier@example.com", language: "en")

    # Travel to a Sunday where the next week has no deliveries
    travel_to Date.new(2024, 1, 7) do
      assert_no_difference -> { BasketComplementMailer.deliveries.size } do
        Notification::BasketComplementWeeklySummary.notify
        perform_enqueued_jobs
      end
    end
  end
end
