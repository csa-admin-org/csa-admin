# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "rake"

class DepotsRakeTest < ActiveSupport::TestCase
  DepotCandidate = Struct.new(:geocodable, :missing_coordinates, :geocode_result, :geocode_calls, keyword_init: true) do
    def geocodable_address?
      geocodable
    end

    def coordinates_missing?
      missing_coordinates
    end

    def geocode
      self.geocode_calls += 1
      geocode_result
    end
  end

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("depots:geocode_missing")
    Rake::Task["depots:geocode_missing"].reenable
  end

  test "geocode missing geocodes kept depots with complete addresses and missing coordinates" do
    depot = DepotCandidate.new(geocodable: true, missing_coordinates: true, geocode_result: true, geocode_calls: 0)
    complete_depot = DepotCandidate.new(geocodable: true, missing_coordinates: false, geocode_result: true, geocode_calls: 0)
    incomplete_depot = DepotCandidate.new(geocodable: false, missing_coordinates: true, geocode_result: true, geocode_calls: 0)

    Geocoding.stub(:enabled?, true) do
      Tenant.stub(:switch_each, ->(&block) { block.call("acme") }) do
        Depot.stub(:kept, [ depot, complete_depot, incomplete_depot ]) do
          out, = capture_io { Rake::Task["depots:geocode_missing"].invoke }

          assert_includes out, "acme: processed=1 updated=1 failed=0"
          assert_includes out, "Total: processed=1 updated=1 failed=0"
        end
      end
    end

    assert_equal 1, depot.geocode_calls
    assert_equal 0, complete_depot.geocode_calls
    assert_equal 0, incomplete_depot.geocode_calls
  end

  test "geocode missing runs when maps feature is disabled" do
    disable_maps
    depot = DepotCandidate.new(geocodable: true, missing_coordinates: true, geocode_result: true, geocode_calls: 0)

    Geocoding.stub(:enabled?, true) do
      Tenant.stub(:switch_each, ->(&block) { block.call("acme") }) do
        Depot.stub(:kept, [ depot ]) do
          out, = capture_io { Rake::Task["depots:geocode_missing"].invoke }

          assert_includes out, "acme: processed=1 updated=1 failed=0"
          assert_includes out, "Total: processed=1 updated=1 failed=0"
        end
      end
    end

    assert_equal 1, depot.geocode_calls
  end

  private

  def disable_maps
    org(features: Current.org.features - [ :maps ])
  end
end
