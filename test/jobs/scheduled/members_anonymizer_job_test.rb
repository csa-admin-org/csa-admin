# frozen_string_literal: true

require "test_helper"

class Scheduled::MembersAnonymizerJobTest < ActiveJob::TestCase
  test "anonymizes discarded members past delay window" do
    member = discardable_member
    member.discard
    member.update_columns(discarded_at: 31.days.ago)

    assert_not member.anonymized?

    perform_enqueued_jobs do
      Scheduled::MembersAnonymizerJob.perform_later
    end

    assert member.reload.anonymized?
  end

  test "does not anonymize discarded members within delay window" do
    member = discardable_member
    member.discard
    member.update_columns(discarded_at: 29.days.ago)

    perform_enqueued_jobs do
      Scheduled::MembersAnonymizerJob.perform_later
    end

    assert_not member.reload.anonymized?
  end

  test "does not anonymize already anonymized members" do
    member = discardable_member
    member.discard
    member.update_columns(discarded_at: 31.days.ago)
    member.anonymize!

    original_name = member.name

    perform_enqueued_jobs do
      Scheduled::MembersAnonymizerJob.perform_later
    end

    assert_equal original_name, member.reload.name
  end

  test "does not anonymize non-discarded members" do
    member = discardable_member
    original_name = member.name

    perform_enqueued_jobs do
      Scheduled::MembersAnonymizerJob.perform_later
    end

    assert_equal original_name, member.reload.name
    assert_not member.anonymized?
  end

  test "anonymizes multiple eligible members" do
    member1 = discardable_member
    member1.discard
    member1.update_columns(discarded_at: 31.days.ago)

    member2 = discardable_member
    member2.discard
    member2.update_columns(discarded_at: 35.days.ago)

    perform_enqueued_jobs do
      Scheduled::MembersAnonymizerJob.perform_later
    end

    assert member1.reload.anonymized?
    assert member2.reload.anonymized?
  end
end
