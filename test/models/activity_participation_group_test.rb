# frozen_string_literal: true

require "test_helper"

class ActivityParticipationGroupTest < ActiveSupport::TestCase
  test "groups similar activity participations together" do
    activity1 = activities(:harvest)
    activity2 = activities(:harvest_afternoon)
    date = activity1.date
    activity3 = create_activity(date: date, start_time: "11:00", end_time: "12:00", description_en: "Picking vegetables")
    activity4 = create_activity(date: date, start_time: "12:00", end_time: "13:00", description_en: "Picking vegetables")

    part1 = activity_participations(:john_harvest)
    part2 = ActivityParticipation.create!(member: members(:john), activity: activity2, participants_count: 2, state: "pending", admins_notified_at: "2024-06-01")
    part3 = ActivityParticipation.create!(member: members(:john), activity: activity3, participants_count: 2, state: "pending", admins_notified_at: "2024-06-01")
    part4 = ActivityParticipation.create!(member: members(:john), activity: activity4, participants_count: 2, state: "pending", admins_notified_at: "2024-06-01")

    groups = ActivityParticipationGroup.group([ part1, part2, part3, part4 ])
    group = groups.first

    assert_equal "8:30-12:00, 11:00-13:00, 13:30-17:00", group.activity.period
    assert_equal activity1.date, group.activity.date
    assert_equal 2, group.participants_count
    assert_equal members(:john), group.member
    assert_equal [ activity1.id, activity2.id ], group.activity_id
  end
end
