# frozen_string_literal: true

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

  def can_discard?
    inactive? &&
      invoices.where(state: %w[processing open]).none? &&
      memberships.none?(&:billable?) &&
      shop_orders.pending.none?
  end

  def discardability_reasons
    reasons = []
    reasons << :not_inactive unless inactive?
    reasons << :open_invoices if invoices.where(state: %w[processing open]).any?
    reasons << :billable_memberships if memberships.any?(&:billable?)
    reasons << :pending_shop_orders if shop_orders.pending.any?
    reasons
  end

  def can_delete?
    pending? || (inactive? &&
      memberships.none? &&
      invoices.none? &&
      payments.none? &&
      shop_orders.none?)
  end

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

  def active_emails
    return [] if discarded?

    super
  end

  # Nil for anonymized members to prevent linking documents back to identifiers.
  def display_id
    anonymized? ? nil : id
  end

  private

  def revoke_sessions
    sessions.find_each(&:revoke!)
  end
end
