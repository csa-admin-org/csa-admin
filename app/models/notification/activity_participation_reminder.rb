# frozen_string_literal: true

class Notification::ActivityParticipationReminder < Notification::Base
  mail_template :activity_participation_reminder

  def notify
    return unless Current.org.feature?("activity")

    ActivityParticipationGroup.group(eligible_participations).each do |group|
      deliver(activity_participation_ids: group.ids)
      group.touch(:latest_reminder_sent_at)
    end
  end

  private

  def eligible_participations
    ActivityParticipation
      .future
      .includes(:activity, :member)
      .select(&:reminderable?)
      .select(&:can_send_email?)
  end
end
