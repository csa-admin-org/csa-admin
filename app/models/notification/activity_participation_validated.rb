# frozen_string_literal: true

class Notification::ActivityParticipationValidated < Notification::Base
  mail_template :activity_participation_validated

  def notify
    return unless Current.org.feature?("activity")
    return unless mail_template_active?

    ActivityParticipationGroup.group(eligible_participations).each do |group|
      deliver_later(activity_participation_ids: group.ids)
      group.touch(:review_sent_at)
    end
  end

  private

  def eligible_participations
    ActivityParticipation
      .where(validated_at: 3.days.ago..)
      .review_not_sent
      .includes(:activity, :member)
      .select(&:can_send_email?)
  end
end
