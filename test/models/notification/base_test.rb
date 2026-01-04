# frozen_string_literal: true

require "test_helper"

class Notification::BaseTest < ActiveSupport::TestCase
  class TestNotification < Notification::Base
    cattr_accessor :notified, default: false

    def notify
      self.class.notified = true
    end
  end

  class TestNotificationWithMailTemplate < Notification::Base
    mail_template :membership_renewal_reminder
  end

  setup do
    TestNotification.notified = false
  end

  test "notify raises NotImplementedError when not overridden" do
    assert_raises(NotImplementedError) do
      Notification::Base.notify
    end
  end

  test "notify calls instance notify method" do
    TestNotification.notify

    assert TestNotification.notified
  end

  test "notify_later enqueues a NotificationJob" do
    assert_enqueued_jobs 1, only: NotificationJob do
      TestNotification.notify_later
    end
  end

  test "NotificationJob executes the notification" do
    perform_enqueued_jobs do
      TestNotification.notify_later
    end

    assert TestNotification.notified
  end

  test "mail_template DSL sets mail_template_title" do
    assert_equal :membership_renewal_reminder, TestNotificationWithMailTemplate.mail_template_title
    assert_nil TestNotification.mail_template_title
  end

  test "mail_template_active? returns true when mail template is active" do
    mail_templates(:membership_renewal_reminder).update!(active: true)

    notification = TestNotificationWithMailTemplate.new
    assert notification.send(:mail_template_active?)
  end

  test "mail_template_active? returns false when mail template is inactive" do
    mail_templates(:membership_renewal_reminder).update!(active: false)

    notification = TestNotificationWithMailTemplate.new
    refute notification.send(:mail_template_active?)
  end

  test "mail_template_active? returns false when no mail template defined" do
    notification = TestNotification.new
    refute notification.send(:mail_template_active?)
  end
end
