# frozen_string_literal: true

# Handles the complete renewal workflow for memberships.
#
# This concern manages the lifecycle of membership renewals, including:
# - Tracking renewal state (pending, opened, canceled, renewed)
# - Opening renewals and sending notification emails
# - Processing renewal decisions (renew or cancel)
# - Maintaining links between previous and renewed memberships
#
# Renewal States:
#   - renewal_pending: Membership can be renewed but no action taken yet
#   - renewal_opened: Renewal email sent, waiting for member decision
#   - renewal_canceled: Member chose not to renew
#   - renewed: Member renewed and next year's membership exists
#
module Membership::Renewal
  extend ActiveSupport::Concern

  STATES = %w[
    renewal_pending
    renewal_opened
    renewal_canceled
    renewed
  ].freeze

  included do
    attr_accessor :renewal_decision

    scope :renewed, -> { where.not(renewed_at: nil) }
    scope :not_renewed, -> { where(renewed_at: nil) }
    scope :renewal_state_eq, ->(state) {
      case state.to_sym
      when :renewal_pending
        not_renewed.where(renew: true, renewal_opened_at: nil)
      when :renewal_opened
        not_renewed.where(renew: true).where.not(renewal_opened_at: nil)
      when :renewal_canceled
        where(renew: false)
      when :renewed
        renewed
      end
    }

    before_save :set_renew
    after_update :keep_renewed_membership_up_to_date!
  end

  def renewal_state
    if renewed?
      :renewed
    elsif canceled?
      :renewal_canceled
    elsif renewal_opened?
      :renewal_opened
    else
      :renewal_pending
    end
  end

  def mark_renewal_as_pending!
    raise "cannot mark renewal as pending on an already renewed membership" if renewed?
    raise "renewal already pending" if renew?

    self[:renew] = true
    self[:renewal_annual_fee] = nil
    save!
  end

  def open_renewal!
    unless MailTemplate.active_template(:membership_renewal)
      raise "membership_renewal mail template not active"
    end
    raise "already renewed" if renewed?
    raise "`renew` must be true before opening renewal" unless renew?
    unless Delivery.any_in_year?(fy_year + 1)
      raise MembershipRenewal::MissingDeliveriesError, "Deliveries for next fiscal year are missing."
    end
    return unless can_send_email?

    MailTemplate.deliver(:membership_renewal,
      membership: self)
    touch(:renewal_opened_at)
  end

  def can_open_renewal?
    can_send_email? && fy_year == Current.fy_year
  end

  def renewal_pending?
    renew? && !renewed? && !renewal_opened_at?
  end

  def renewal_opened?
    renew? && !renewed? && renewal_opened_at?
  end

  def renew!(attrs = {})
    return if renewed?
    raise "`renew` must be true for renewing" unless renew?

    renewal = MembershipRenewal.new(self)

    transaction do
      renewal.renew!(attrs)
      self[:renewal_note] = attrs[:renewal_note]
      self[:renewed_at] = Time.current
      save!
    end
  end

  def renewed?
    renewed_at?
  end

  def can_renew?
    delivery_cycle&.future_deliveries&.any?
  end

  def renewed_membership
    return unless renewed?

    @renewed_membership ||= member.memberships.during_year(fy_year + 1).first
  end

  def previous_membership
    @previous_membership ||= member.memberships.during_year(fy_year - 1).first
  end

  def cancel!(attrs = {})
    return if canceled?
    raise "cannot cancel an already renewed membership" if renewed?

    if Current.org.annual_fee?
      if ActiveRecord::Type::Boolean.new.cast(attrs[:renewal_annual_fee])
        self[:renewal_annual_fee] = Current.org.annual_fee
      end
    end
    self[:renewal_note] = attrs[:renewal_note]
    self[:renewal_opened_at] = nil
    self[:renewed_at] = nil
    self[:renew] = false
    save!
  end

  def canceled?
    persisted? && !renew?
  end

  private

  def set_renew
    return if renew_changed? && !renew? # Explicit cancellation, don't override

    if ended_on_changed?
      self.renew = (ended_on >= Current.fy_range.max)
    end
  end

  def update_renewal_of_previous_membership_after_creation
    if previous_membership&.renewal_state&.in?(%i[renewal_pending renewal_opened])
      previous_membership.update_columns(
        renewal_opened_at: nil,
        renewed_at: created_at,
        renew: true)
    end
  end

  def update_renewal_of_previous_membership_after_deletion
    return unless previous_membership&.renewed_at?

    previous_membership.update_columns(
      renewal_opened_at: nil,
      renewed_at: nil,
      renew: fy_year > Current.fy_year)
  end

  def keep_renewed_membership_up_to_date!
    return unless renewed_membership
    return unless saved_change_to_attribute?(:billing_year_division)

    renewed_membership.update_column(:billing_year_division, billing_year_division)
  end
end
