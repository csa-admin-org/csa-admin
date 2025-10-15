# frozen_string_literal: true

module Shared
  module BulkDatesInsert
    extend ActiveSupport::Concern

    included do
      def setup
        super
        shared_class = self.class.name.gsub(/Test$/, "").classify.constantize
        @model ||= shared_class.new(date: nil)
      end

      test "bulk_dates is nil with a date set" do
        @model.date = Date.current
        assert_nil @model.bulk_dates
      end

      test "bulk_dates includes all the days between starts and ends dates" do
        @model.bulk_dates_starts_on = Date.current
        @model.bulk_dates_ends_on = Date.tomorrow
        @model.bulk_dates_weeks_frequency = 1
        @model.bulk_dates_wdays = Array(0..6)

        assert_equal [ Date.current, Date.tomorrow ], @model.bulk_dates
      end

      test "bulk_dates includes all the days between starts and ends dates following wdays" do
        @model.bulk_dates_starts_on = Date.current.monday
        @model.bulk_dates_ends_on = Date.current.sunday
        @model.bulk_dates_weeks_frequency = 1
        @model.bulk_dates_wdays = [ 0, 1, 2 ]

        assert_equal [
          Date.current.monday,
          Date.current.monday + 1.day,
          Date.current.sunday
        ], @model.bulk_dates
      end

      test "bulk_dates includes all the days between starts and ends dates with frequency" do
        @model.bulk_dates_starts_on = Date.current.monday
        @model.bulk_dates_ends_on = Date.current.sunday + 1.month
        @model.bulk_dates_weeks_frequency = 2
        @model.bulk_dates_wdays = [ 1 ]

        assert_equal [
          Date.current.monday,
          Date.current.monday + 2.weeks,
          Date.current.monday + 4.weeks
        ], @model.bulk_dates
      end

      test "save includes all the days between starts and ends dates following wdays" do
        travel_to "2018-01-01"
        @model.bulk_dates_starts_on = "2018-11-05"
        @model.bulk_dates_ends_on = "2018-12-11"
        @model.bulk_dates_weeks_frequency = 2
        @model.bulk_dates_wdays = Array(0..6)

        assert_equal 21, @model.bulk_dates.size
        assert_difference("#{@model.class.name}.count", 21) do
          @model.save
        end
      end
    end
  end
end
