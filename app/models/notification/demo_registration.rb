# frozen_string_literal: true

class Notification::DemoRegistration < Notification::Base
  def notify
    return unless Tenant.demo?

    eligible_admins.each do |admin|
      send_notification!(admin)
    end
  end

  private

  def eligible_admins
    Admin
      .where.not(email: ENV["ULTRA_ADMIN_EMAIL"])
      .where(demo_registration_notification_sent_at: nil)
      .where(created_at: ..1.hour.ago)
      .select { |admin| admin.meaningfully_explored_demo? }
  end

  def send_notification!(admin)
    AdminMailer.with(
      admin: admin,
      message: admin.demo_message.presence,
      tenant: Tenant.current
    ).demo_registration_notification_email.deliver_later

    admin.touch(:demo_registration_notification_sent_at)
  end
end
