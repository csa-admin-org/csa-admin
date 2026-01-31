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

  def anonymized?
    anonymized_at?
  end

  private

  def revoke_sessions
    sessions.find_each(&:revoke!)
  end
end
