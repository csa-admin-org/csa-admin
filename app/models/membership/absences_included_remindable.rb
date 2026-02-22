# frozen_string_literal: true

module Membership::AbsencesIncludedRemindable
  extend ActiveSupport::Concern

  included do
    scope :absences_included_remindable, -> {
      current
        .where(absences_included_reminder_sent_at: nil)
        .where(absences_included: 1..)
    }
  end

  class_methods do
    def send_absences_included_reminders
      return unless Current.org.feature?("absence")

      absences_included_remindable.includes(:baskets, :member).find_each do |membership|
        membership.send_absences_included_reminder!
      end
    end
  end

  def absences_included_remindable_on
    first_provisional = baskets.coming.provisionally_absent.first
    return unless first_provisional

    first_provisional.delivery.date - Current.org.absences_included_reminder_period
  end

  def absences_included_reminded?
    absences_included_reminder_sent_at?
  end

  def absences_included_used
    baskets.definitely_absent.count
  end

  def absences_included_remaining
    [ absences_included - absences_included_used, 0 ].max
  end

  def send_absences_included_reminder!
    return unless absences_included_must_be_reminded?

    if Current.org.absences_included_provisional_delivery_mode?
      create_forced_deliveries_for_provisional_baskets!
    end

    MailTemplate.deliver(:absence_included_reminder, membership: self)
    update_column(:absences_included_reminder_sent_at, Time.current)
  end

  private

  def absences_included_must_be_reminded?
    return false if absences_included_reminded?

    if remindable_on = absences_included_remindable_on
      Date.current >= remindable_on
    end
  end

  def create_forced_deliveries_for_provisional_baskets!
    baskets.provisionally_absent.each do |basket|
      forced_deliveries.find_or_create_by!(delivery: basket.delivery)
    end
  end
end
