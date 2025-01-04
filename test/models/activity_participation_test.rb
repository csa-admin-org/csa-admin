# frozen_string_literal: true

require "test_helper"

class ActivityParticipationTest < ActiveSupport::TestCase
  test "validates activity participants limit" do
    travel_to "2024-01-01"
    activity = activities(:harvest)
    activity.update!(participants_limit: 5)
    assert_equal 3, activity.participants_count

    participation = ActivityParticipation.build(activity: activity, participants_count: 3)
    participation.validate
    assert_not participation.errors[:participants_count].empty?
  end

  test "validates activity participants limit when many participations" do
    travel_to "2024-01-01"
    activity1 = activities(:harvest)
    activity1.update!(participants_limit: 5)
    assert_equal 3, activity1.participants_count

    activity2 = activities(:harvest_afternoon)
    activity2.update!(participants_limit: 1)
    assert_equal 0, activity2.participants_count

    participation = ActivityParticipation.create(
      member: members(:martha),
      activity: nil,
      activity_ids: [ activity1.id, activity2.id ],
      participants_count: 2
    )
    assert_equal [ "must be less than or equal to 1" ], participation.errors[:participants_count]
  end

  test "does not validate activity participants limit when update" do
    activity = activities(:harvest)
    activity.update!(participants_limit: 3)
    assert_equal 3, activity.participants_count

    participation = activity_participations(:john_harvest)
    participation.update(participants_count: 3)
    assert participation.valid?
  end

  test "validates carpooling phone and city presence when carpooling is checked" do
    participation = ActivityParticipation.build(
      activity: activities(:harvest),
      participants_count: 1,
      carpooling: "1"
    )
    participation.validate

    assert_not participation.errors[:carpooling_phone].empty?
    assert_not participation.errors[:carpooling_city].empty?
  end

  test "validates carpooling phone format when carpooling is checked" do
    travel_to "2024-01-01"
    participation = ActivityParticipation.build(
      activity: activities(:harvest),
      participants_count: 1,
      carpooling_phone: "foo",
      carpooling: "1"
    )
    participation.validate

    assert_not participation.errors[:carpooling_phone].empty?
  end

  test "invoice_all_missing noop if no activity price" do
    org(activity_price: 0)
    assert_no_difference "Invoice.count" do
      ActivityParticipation.invoice_all_missing(2024)
      perform_enqueued_jobs
    end
  end

  test "invoice_all_missing noop if no missing activity participations" do
    assert_no_difference "Invoice.count" do
      ActivityParticipation.invoice_all_missing(2022)
      perform_enqueued_jobs
    end
  end

  test "invoice_all_missing creates invoices for missing activity participations" do
    Current.org.update!(activity_price: 90)
    assert_difference "Invoice.count" do
      ActivityParticipation.invoice_all_missing(2024)
      perform_enqueued_jobs
    end
  end

  test "validate! sets states column" do
    travel_to "2024-08-01"
    admin = admins(:super)
    participation = activity_participations(:john_harvest)

    assert_changes -> { participation.reload.state }, from: "pending", to: "validated" do
      participation.validate!(admin)
    end
    assert_not_nil participation.validated_at
    assert_equal admin.id, participation.validator_id
    assert_nil participation.rejected_at
    assert_nil participation.review_sent_at
  end

  test "does not validate already validated activity participations" do
    travel_to "2024-08-01"
    admin = admins(:super)
    participation = activity_participations(:john_harvest)

    assert participation.validate!(admin)
    participation.reload

    assert_nil participation.validate!(admin)
  end

  test "does not validate future activity participation" do
    travel_to "2024-06-30"
    admin = admins(:super)
    participation = activity_participations(:john_harvest)

    assert_nil participation.validate!(admin)
  end

  test "reject! sets states column" do
    travel_to "2024-08-01"
    admin = admins(:super)
    participation = activity_participations(:john_harvest)

    assert_changes -> { participation.reload.state }, from: "pending", to: "rejected" do
      participation.reject!(admin)
    end
    assert_not_nil participation.rejected_at
    assert_equal admin.id, participation.validator_id
    assert_nil participation.validated_at
    assert_nil participation.review_sent_at
  end

  test "does not reject already rejected activity participations" do
    travel_to "2024-08-01"
    admin = admins(:super)
    participation = activity_participations(:john_harvest)

    assert participation.reject!(admin)
    participation.reload

    assert_nil participation.reject!(admin)
  end

  test "does not reject future activity participation" do
    travel_to "2024-06-30"
    admin = admins(:super)
    participation = activity_participations(:john_harvest)

    assert_nil participation.reject!(admin)
  end

  test "carpooling resets carpooling phone and city if carpooling = 0" do
    participation = ActivityParticipation.create!(
      member: members(:martha),
      activity: activities(:harvest),
      carpooling: "0",
      carpooling_phone: "+41 79 123 45 67",
      carpooling_city: "Nowhere")

    assert_nil participation.carpooling_phone
    assert_nil participation.carpooling_city
  end

  test "destroyable? returns true when not the same day" do
    org(activity_participation_deletion_deadline_in_days: nil)
    participation = activity_participations(:john_harvest)
    participation.created_at = "2024-06-28 +02:00"

    travel_to "2024-06-30 +02:00"
    assert participation.destroyable?
  end

  test "destroyable? returns false when the same day" do
    org(activity_participation_deletion_deadline_in_days: nil)
    participation = activity_participations(:john_harvest)
    participation.created_at = "2024-06-29 +02:00"

    travel_to "2024-07-01 +02:00"
    assert_not participation.destroyable?
  end

  test "destroyable? returns true when a deletion deadline is set and creation is in the last 24h" do
    org(activity_participation_deletion_deadline_in_days: nil)
    participation = activity_participations(:john_harvest)
    participation.created_at = "2024-06-29 +02:00"

    travel_to "2024-06-30 +02:00"
    assert participation.destroyable?
  end

  test "destroyable? returns false when a deletion deadline is set and creation has been done more than 24h ago" do
    org(activity_participation_deletion_deadline_in_days: 10)
    participation = activity_participations(:john_harvest)
    participation.created_at = "2024-06-20 +02:00"

    travel_to "2024-06-21 +02:00"
    assert_not participation.destroyable?
  end

  test "reminderable? is true when activity participation is in less than three days and never reminded" do
    participation = activity_participations(:john_harvest)
    participation.latest_reminder_sent_at = nil

    travel_to "2024-06-28 +02:00"
    assert participation.reminderable?
  end

  test "reminderable? is false when activity participation is in less than three days but already reminded" do
    participation = activity_participations(:john_harvest)
    participation.latest_reminder_sent_at = "2024-06-28 +02:00"

    travel_to "2024-06-28 +02:00"
    assert_not participation.reminderable?
  end

  test "reminderable? is false when activity participation is in more than 3 days" do
    participation = activity_participations(:john_harvest)
    participation.latest_reminder_sent_at = nil

    travel_to "2024-06-27 +02:00"
    assert_not participation.reminderable?
  end

  test "reminderable? is false when activity participation has passed" do
    participation = activity_participations(:john_harvest)
    participation.latest_reminder_sent_at = nil

    travel_to "2024-07-02 +02:00"
    assert_not participation.reminderable?
  end

  test "updates membership activity_participations_accepted" do
    travel_to "2024-08-01"
    membership = memberships(:john)
    participation = ActivityParticipation.build(
      activity: activities(:harvest_afternoon),
      member: members(:john),
      participants_count: 2)

    assert_difference -> { membership.reload.activity_participations_accepted }, 2 do
      participation.save!
    end

    assert_difference -> { membership.reload.activity_participations_accepted }, -2 do
      participation.reject!(admins(:super))
    end
  end
end
