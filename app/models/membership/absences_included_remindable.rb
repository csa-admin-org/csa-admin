# frozen_string_literal: true

# Handles the absences included reminder functionality for memberships.
#
# In provisional_delivery mode, creates forced deliveries for all provisional baskets.
# In both modes, sends a reminder email to the member.
#
# Usage:
#   Membership.send_absences_included_reminders  # Called by scheduled job
#   membership.send_absences_included_reminder!  # Process single membership
#
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
      return unless Current.org.absences_included_reminder_enabled?

      absences_included_remindable.includes(:baskets, :member).find_each do |membership|
        membership.send_absences_included_reminder!
      end
    end
  end

  # Calculates the date when the absences included reminder should be sent.
  # This is the date of the first coming provisional basket minus the configured weeks.
  # Returns nil if there are no coming provisional baskets.
  def absences_included_remindable_on
    first_provisional = baskets.coming.provisionally_absent.first
    return unless first_provisional

    first_provisional.delivery.date - Current.org.absences_included_reminder_period
  end

  def absences_included_reminded?
    absences_included_reminder_sent_at?
  end

  # Count of baskets with definitive absences (created by member or admin)
  def absences_included_used
    baskets.definitely_absent.count
  end

  # Remaining absences that can still be used (never negative)
  def absences_included_remaining
    [ absences_included - absences_included_used, 0 ].max
  end

  def send_absences_included_reminder!
    return unless absences_included_must_be_reminded?

    if Current.org.absences_included_provisional_delivery_mode?
      create_forced_deliveries_for_provisional_baskets!
    end

    MailTemplate.deliver_later(:absence_included_reminder, membership: self)
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
