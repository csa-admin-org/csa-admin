# frozen_string_literal: true

class Notification::AdminNewActivityParticipation < Notification::Base
  def notify
    return unless Current.org.feature?("activity")

    ActivityParticipationGroup.group(eligible_participations).each do |group|
      notify_admins(group)
      group.touch(:admins_notified_at)
    end
  end

  private

  def eligible_participations
    ActivityParticipation
      .where(created_at: 1.day.ago.., admins_notified_at: nil)
      .includes(:activity, :member, :session)
  end

  def notify_admins(group)
    attrs = {
      activity_participation_ids: group.ids,
      skip: group.session&.admin
    }
    Admin.notify!(:new_activity_participation, **attrs)
    Admin.notify!(:new_activity_participation_with_note, **attrs) if group.note?
  end
end
