# frozen_string_literal: true

require "test_helper"
require "ostruct"

class DepotGeocodingJobTest < ActiveJob::TestCase
  test "updates blank coordinates from first geocoding result" do
    depot = depots(:farm)
    depot.update_columns(latitude: nil, longitude: nil)

    with_geocoding_enabled do
      stub_geocoding_results([ 46.992979, 6.931932 ]) do
        perform_geocoding_job(depot)
      end
    end

    assert_in_delta 46.992979, depot.reload.latitude.to_f
    assert_in_delta 6.931932, depot.longitude.to_f
  end

  test "does not overwrite existing coordinates unless forced" do
    depot = depots(:farm)
    depot.update_columns(latitude: 46.1, longitude: 6.1)

    with_geocoding_enabled do
      stub_geocoding_results([ 46.992979, 6.931932 ]) do
        perform_geocoding_job(depot)
      end
    end

    assert_in_delta 46.1, depot.reload.latitude.to_f
    assert_in_delta 6.1, depot.longitude.to_f

    with_geocoding_enabled do
      stub_geocoding_results([ 46.992979, 6.931932 ]) do
        perform_geocoding_job(depot, force: true)
      end
    end

    assert_in_delta 46.992979, depot.reload.latitude.to_f
    assert_in_delta 6.931932, depot.longitude.to_f
  end

  test "leaves coordinates blank when no result is found" do
    depot = depots(:farm)
    depot.update_columns(latitude: nil, longitude: nil)

    with_geocoding_enabled do
      stub_geocoding_search([]) do
        perform_geocoding_job(depot)
      end
    end

    assert_nil depot.reload.latitude
    assert_nil depot.longitude
  end

  test "swallows geocoding errors" do
    depot = depots(:farm)
    depot.update_columns(latitude: nil, longitude: nil)
    failure = ->(_address) { raise Geocoder::Error, "temporary failure" }

    with_geocoding_enabled do
      stub_geocoding_search(failure) do
        perform_geocoding_job(depot)
      end
    end

    assert_nil depot.reload.latitude
    assert_nil depot.longitude
  end

  test "geocodes when maps feature is disabled" do
    disable_maps
    depot = depots(:farm)
    depot.update_columns(latitude: nil, longitude: nil)

    with_geocoding_enabled do
      stub_geocoding_results([ 46.992979, 6.931932 ]) do
        perform_geocoding_job(depot, force: true)
      end
    end

    assert_in_delta 46.992979, depot.reload.latitude.to_f
    assert_in_delta 6.931932, depot.longitude.to_f
  end

  private

  def perform_geocoding_job(depot, force: false)
    perform_enqueued_jobs only: DepotGeocodingJob do
      DepotGeocodingJob.perform_later(depot, force: force)
    end
  end

  def stub_geocoding_results(coordinates)
    result = OpenStruct.new(coordinates: coordinates)
    stub_geocoding_search([ result ]) { yield }
  end

  def stub_geocoding_search(response)
    original = Geocoding::Nominatim.method(:search)
    Geocoding::Nominatim.define_singleton_method(:search) do |address|
      response.respond_to?(:call) ? response.call(address) : response
    end
    yield
  ensure
    Geocoding::Nominatim.define_singleton_method(:search, original)
  end

  def disable_maps
    org(features: Current.org.features - [ :maps ])
  end

  def with_geocoding_enabled
    previous = Rails.application.config.x.geocoding.enabled
    Rails.application.config.x.geocoding.enabled = true
    yield
  ensure
    Rails.application.config.x.geocoding.enabled = previous
  end
end
