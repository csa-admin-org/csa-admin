# frozen_string_literal: true

require "test_helper"

class ActivityParticipationMailerTest < ActionMailer::TestCase
  test "reminder_email" do
    template = MailTemplate.new(title: :activity_participation_reminder)
    participation = activity_participations(:john_harvest)
    group = ActivityParticipationGroup.group([ participation ]).first

    mail = ActivityParticipationMailer.with(
      template: template,
      activity_participation_ids: group.ids,
    ).reminder_email

    assert_equal "Upcoming activity (1 July 2024)", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "activity-participation-reminder", mail.tag
    assert_includes mail.body, "<strong>Date:</strong> Monday 1 July 2024"
    assert_includes mail.body, "<strong>Schedule:</strong> 8:30-12:00"
    assert_includes mail.body, "<strong>Activity:</strong> Help with the harvest"
    assert_includes mail.body, "<strong>Description:</strong> Picking vegetables"
    assert_includes mail.body, "<strong>Location:</strong> <a href=\"https://farm.example.com\" target=\"_blank\" rel=\"noreferrer noopener\">Farm</a>"
    assert_includes mail.body, "<strong>Participants:</strong> 2"
    assert_includes mail.body, "<strong>Jane Doe</strong>: +41 79 123 45 67 (La Chaux-de-Fonds)"
    assert_includes mail.body, "https://members.acme.test/activity_participations"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "validated_email" do
    template = MailTemplate.new(title: :activity_participation_validated)
    participation = activity_participations(:john_harvest)

    mail = ActivityParticipationMailer.with(
      template: template,
      activity_participation_ids: participation.id
    ).validated_email

    assert_equal "Activity confirmed 🎉", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "activity-participation-validated", mail.tag
    assert_includes mail.body, "<strong>Date:</strong> Monday 1 July 2024"
    assert_includes mail.body, "<strong>Schedule:</strong> 8:30-12:00"
    assert_includes mail.body, "<strong>Activity:</strong> Help with the harvest"
    assert_includes mail.body, "<strong>Description:</strong> Picking vegetables"
    assert_includes mail.body, "<strong>Location:</strong> <a href=\"https://farm.example.com\" target=\"_blank\" rel=\"noreferrer noopener\">Farm</a>"
    assert_includes mail.body, "<strong>Participants:</strong> 2"
    assert_includes mail.body, "https://members.acme.test/activity_participations"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "rejected_email" do
    template = MailTemplate.new(title: :activity_participation_rejected)
    participation = activity_participations(:john_harvest)

    mail = ActivityParticipationMailer.with(
      template: template,
      activity_participation_ids: participation.id
    ).rejected_email

    assert_equal "Activity rejected 😬", mail.subject
    assert_equal [ "john@doe.com" ], mail.to
    assert_equal "activity-participation-rejected", mail.tag
    assert_includes mail.body, "<strong>Date:</strong> Monday 1 July 2024"
    assert_includes mail.body, "<strong>Schedule:</strong> 8:30-12:00"
    assert_includes mail.body, "<strong>Activity:</strong> Help with the harvest"
    assert_includes mail.body, "<strong>Description:</strong> Picking vegetables"
    assert_includes mail.body, "<strong>Location:</strong> <a href=\"https://farm.example.com\" target=\"_blank\" rel=\"noreferrer noopener\">Farm</a>"
    assert_includes mail.body, "<strong>Participants:</strong> 2"
    assert_includes mail.body, "https://members.acme.test/activity_participations"
    assert_equal "Acme <info@acme.test>", mail[:from].decoded
    assert_equal "outbound", mail[:message_stream].to_s
  end

  test "default activity templates open locations safely in a new tab" do
    %w[
      activity_participation_rejected
      activity_participation_reminder
      activity_participation_validated
    ].each do |template_name|
      body = render_default_template(template_name)

      assert_includes body, '<a href="https://farm.example.com" target="_blank" rel="noreferrer noopener">Farm</a>'
      assert_not_includes body, 'target="_black"'
    end
  end

  private

  def render_default_template(template_name)
    participation = activity_participations(:john_harvest)

    Liquid::Template.parse(
      LiquidErb.render("mail_templates/#{template_name}", locale: :en)
    ).render!(
      "organization" => Liquid::OrganizationDrop.new(Current.org),
      "member" => Liquid::MemberDrop.new(participation.member),
      "activity" => Liquid::ActivityDrop.new(participation.activity),
      "activity_participation" => Liquid::ActivityParticipationDrop.new(participation),
      strict_variables: true)
  end
end
