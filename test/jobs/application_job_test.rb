# frozen_string_literal: true

require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  test "discards a job whose record was deleted" do
    DepotGeocodingJob.perform_later(depots(:farm))

    fetch_raising(GlobalID::Locator::RecordNotFound.new("missing")) do
      assert_nothing_raised do
        perform_enqueued_jobs only: DepotGeocodingJob
      end
    end

    assert_no_enqueued_jobs only: DepotGeocodingJob
  end

  test "does not discard a transient deserialization error" do
    DepotGeocodingJob.perform_later(depots(:farm))

    error = fetch_raising(RuntimeError.new("database is locked")) do
      assert_raises(ActiveJob::DeserializationError) do
        perform_enqueued_jobs only: DepotGeocodingJob
      end
    end

    assert_not_kind_of ActiveJob::DeserializationError::RecordNotFound, error
    assert_equal "database is locked", error.cause.message
  end

  private

  def fetch_raising(error)
    fetching = ->(*) { raise error }
    GlobalID::Locator.stub(:fetch, fetching) { yield }
  end
end
