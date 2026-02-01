# frozen_string_literal: true

# Handles soft-deletion (discard) for GDPR-compliant member removal.
# Preserves historical data while marking members as "gone".
#
# A member can be discarded if inactive with no financial obligations.
# A member can be fully deleted only if no historical data exists.
#
# On discard:
# - All sessions are revoked (prevents login)
module Member::Discardable
  extend ActiveSupport::Concern

  included do
    include Discard::Model

    scope :kept, -> { undiscarded }

    after_discard :revoke_sessions
    before_undiscard do
      raise "Cannot undiscard anonymized member ##{id}" if anonymized?
    end
  end

  # Can discard if inactive with no pending financial obligations
  def can_discard?
    inactive? &&
      invoices.where(state: %w[processing open]).none? &&
      memberships.none?(&:billable?) &&
      shop_orders.pending.none?
  end

  # Returns array of i18n keys explaining why member cannot be discarded.
  # Used to display clear feedback when deletion is not possible.
  def discardability_reasons
    reasons = []
    reasons << :not_inactive unless inactive?
    reasons << :open_invoices if invoices.where(state: %w[processing open]).any?
    reasons << :billable_memberships if memberships.any?(&:billable?)
    reasons << :pending_shop_orders if shop_orders.pending.any?
    reasons
  end

  # Can fully delete only if no historical data exists
  def can_delete?
    pending? || (inactive? &&
      memberships.none? &&
      invoices.none? &&
      payments.none? &&
      shop_orders.none?)
  end

  # Override to use discard pattern
  def can_destroy?
    return false if discarded?

    can_discard? || can_delete?
  end

  def destroy
    if can_delete?
      super
    elsif can_discard?
      discard
    else
      raise "Cannot destroy Member##{id}"
    end
  end

  # Override to block transactional emails for discarded members
  def active_emails
    return [] if discarded?

    super
  end

  # Returns id for exports/display, nil for anonymized members
  # to prevent linking historical documents back to member identifiers.
  def display_id
    anonymized? ? nil : id
  end

  private

  def revoke_sessions
    sessions.find_each(&:revoke!)
  end
end
