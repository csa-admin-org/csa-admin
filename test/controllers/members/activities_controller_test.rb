# frozen_string_literal: true

require "test_helper"

class Members::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  def request(**options)
    host! "members.acme.test"
    get activities_path(options)
  end

  test "returns an RSS feed with coming and available activities" do
    Current.org.update_column(:activity_availability_limit_in_days, 3)

    create_activity(date: 2.days.from_now, title: "Too Soon")
    create_activity(date: 3.days.from_now, title: "Just Good")
    activity = create_activity(date: 3.days.from_now, title: "Full", participants_limit: 1)
    ActivityParticipation.create!(activity: activity, member: members(:john))

    request(format: :rss)

    assert_response :success
    assert_equal "application/rss+xml", response.media_type
    assert_not_includes response.body, "Too Soon"
    assert_includes response.body, "Just Good"
    assert_not_includes response.body, "Full"
  end

  test "returns an RSS feed with coming and extra dates" do
    Current.org.update_column(:activity_availability_limit_in_days, 1)
    create_activity(date: 1.days.from_now, title: "One")
    create_activity(date: 2.days.from_now, title: "Two")
    create_activity(date: 3.days.from_now, title: "Three")

    request(format: :rss, limit: 2)

    assert_response :success
    assert_equal "application/rss+xml", response.media_type
    assert_includes response.body, "One"
    assert_includes response.body, "Two"
    assert_not_includes response.body, "Tnree"
  end

  test "returns an RSS feed with empty item when no available activities" do
    request(format: :rss)

    assert_response :success
    assert_equal "application/rss+xml", response.media_type
    assert_includes response.body, "No half-day work available at the moment."
  end
end
