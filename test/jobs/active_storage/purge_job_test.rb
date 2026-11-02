# frozen_string_literal: true

require "test_helper"

class ActiveStorage::PurgeJobTest < ActiveJob::TestCase
  test "discards a purge whose blob was already deleted" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("pdf"),
      filename: "document.pdf",
      content_type: "application/pdf")
    key = blob.key

    ActiveStorage::PurgeJob.perform_later(blob)
    ActiveStorage::Blob.where(id: blob.id).delete_all

    assert_nothing_raised do
      perform_enqueued_jobs only: ActiveStorage::PurgeJob
    end

    assert_nil ActiveStorage::Blob.find_by(id: blob.id)
    assert blob.service.exist?(key)
    assert_equal [ "ActiveStorage::PurgeJob" ], performed_jobs.map { |job| job["job_class"] }
    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob
  end
end
