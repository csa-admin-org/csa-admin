# frozen_string_literal: true

require "test_helper"

class Scheduled::PromotionsArchiverJobTest < ActiveJob::TestCase
  test "archives promotions whose end date has passed and clears the date" do
    due = travel_to("2026-06-01") {
      Promotion.create!(name: "Due", amount: 10, ends_on: "2026-06-01")
    }
    travel_to "2026-06-02"
    open = Promotion.create!(name: "Open", amount: 10, ends_on: "2026-06-02")

    perform_enqueued_jobs do
      Scheduled::PromotionsArchiverJob.perform_later
    end

    assert_equal "archived", due.reload.state
    assert_nil due.ends_on
    assert_equal "active", open.reload.state
  end
end
