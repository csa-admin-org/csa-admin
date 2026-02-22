# frozen_string_literal: true

# Trial baskets can span two memberships (e.g., member joins in December
# with 4 trial baskets: 2 in December's membership + 2 in January's renewed
# membership). Only the membership where the trial ends should allow cancellation.
module Membership::Trial
  extend ActiveSupport::Concern

  included do
    scope :trial, -> { current.where(remaining_trial_baskets_count: 1..) }
    scope :ongoing, -> { current.where(remaining_trial_baskets_count: 0) }
  end

  def trial?
    remaining_trial_baskets_count.positive?
  end

  def trial_only?
    baskets_count == trial_baskets_count
  end

  def can_member_cancel_trial?
    Current.org.trial_baskets?
      && (current? || future?)
      && !canceled?
      && contains_last_trial_basket?
      && before_first_non_trial_basket?
  end

  def cancel_trial!(attrs = {})
    return unless can_member_cancel_trial?

    last_trial_basket = baskets.trial.last
    return unless last_trial_basket

    self[:ended_on] = last_trial_basket.delivery.date
    cancel!(attrs)
    notify_admins_of_trial_cancelation!
    true
  end

  def notify_admins_of_trial_cancelation!
    Admin.notify!(:membership_trial_cancelation, member: member, membership: self)
  end

  private

  def contains_last_trial_basket?
    last_member_trial_basket = member.baskets.trial.last
    last_member_trial_basket&.membership_id == id
  end

  def before_first_non_trial_basket?
    first_non_trial_basket = baskets.not_trial.first
    return true unless first_non_trial_basket # Only trial baskets, can cancel

    Date.current < first_non_trial_basket.delivery.date
  end
end
