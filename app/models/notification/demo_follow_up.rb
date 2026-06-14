# frozen_string_literal: true

class Notification::DemoFollowUp < Notification::Base
  def notify
    return unless Tenant.demo?

    eligible_admins.each do |admin|
      send_follow_up!(admin)
    end
  end

  private

  def eligible_admins
    Admin
      .where.not(email: ENV["ULTRA_ADMIN_EMAIL"])
      .where(demo_follow_up_sent_at: nil)
      .where.missing(:tickets)
      .select { |admin| eligible?(admin) }
  end

  def eligible?(admin)
    last_visit = admin.last_demo_page_visit_at
    last_visit && admin.meaningfully_explored_demo? && last_visit < 24.hours.ago
  end

  def send_follow_up!(admin)
    setup_handbook_url = Rails.application.routes.url_helpers
      .handbook_page_url(:setup, host: Tenant.admin_host)

    AdminMailer.with(
      admin: admin,
      setup_handbook_url: setup_handbook_url
    ).demo_follow_up_email.deliver_later

    AdminMailer.with(
      admin: admin,
      tenant: Tenant.current
    ).demo_follow_up_notification_email.deliver_later

    admin.touch(:demo_follow_up_sent_at)
  end
end
