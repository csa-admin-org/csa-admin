# frozen_string_literal: true

module Shared
  module BulkDatesInsert
    extend ActiveSupport::Concern

    included do
      def setup
        super
        shared_class = self.class.name.gsub(/Test$/, "").classify.constantize
        @model = shared_class.new(date: nil)
      end

      test "bulk_dates is nil with a date set" do
        @model.date = Date.today
        assert_nil @model.bulk_dates
      end

      test "bulk_dates includes all the days between starts and ends dates" do
        @model.bulk_dates_starts_on = Date.today
        @model.bulk_dates_ends_on = Date.tomorrow
        @model.bulk_dates_weeks_frequency = 1
        @model.bulk_dates_wdays = Array(0..6)

        assert_equal [ Date.today, Date.tomorrow ], @model.bulk_dates
      end

      test "bulk_dates includes all the days between starts and ends dates following wdays" do
        @model.bulk_dates_starts_on = Date.today.monday
        @model.bulk_dates_ends_on = Date.today.sunday
        @model.bulk_dates_weeks_frequency = 1
        @model.bulk_dates_wdays = [ 0, 1, 2 ]

        assert_equal [
          Date.today.monday,
          Date.today.monday + 1.day,
          Date.today.sunday
        ], @model.bulk_dates
      end

      test "bulk_dates includes all the days between starts and ends dates with frequency" do
        @model.bulk_dates_starts_on = Date.today.monday
        @model.bulk_dates_ends_on = Date.today.sunday + 1.month
        @model.bulk_dates_weeks_frequency = 2
        @model.bulk_dates_wdays = [ 1 ]

        assert_equal [
          Date.today.monday,
          Date.today.monday + 2.weeks,
          Date.today.monday + 4.weeks
        ], @model.bulk_dates
      end

      test "save includes all the days between starts and ends dates following wdays" do
        travel_to Date.parse("2018-01-01") do
          @model.bulk_dates_starts_on = Date.parse("2018-11-05")
          @model.bulk_dates_ends_on = Date.parse("2018-11-11") + 1.month
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
end
