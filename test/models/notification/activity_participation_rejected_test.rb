# frozen_string_literal: true

require "test_helper"

class Notification::ActivityParticipationRejectedTest < ActiveSupport::TestCase
  def create_participation(attributes = {})
    activity = activities(:harvest)
    attributes[:member] ||= create_member
    ActivityParticipation.create!(activity: activity, **attributes)
  end

  test "notify sends emails for rejected participations" do
    mail_templates(:activity_participation_rejected).update!(active: true)
    member = create_member(emails: "anybody@doe.com")

    create_participation(review_sent_at: nil, rejected_at: 1.day.ago, member: member)
    create_participation(review_sent_at: nil, validated_at: 1.day.ago)
    create_participation(review_sent_at: Time.current, rejected_at: 1.day.ago)
    create_participation(review_sent_at: nil, rejected_at: 4.days.ago)

    assert_difference -> { ActivityMailer.deliveries.size }, 1 do
      Notification::ActivityParticipationRejected.notify
      perform_enqueued_jobs
    end

    mail = ActivityMailer.deliveries.last
    assert_equal "Activity rejected 😬", mail.subject
    assert_equal [ "anybody@doe.com" ], mail.to
  end

  test "does not send email when template is not active" do
    mail_templates(:activity_participation_rejected).update!(active: false)

    create_participation(review_sent_at: nil, rejected_at: 1.day.ago)

    assert_no_difference -> { ActivityMailer.deliveries.size } do
      Notification::ActivityParticipationRejected.notify
      perform_enqueued_jobs
    end
  end
end
