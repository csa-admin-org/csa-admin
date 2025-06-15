# frozen_string_literal: true

module AbsencesHelper
  def display_absence?
    Current.org.feature?("absence") && current_member.current_or_future_membership
  end

  def next_shiftable_basket
    return unless Current.org.basket_shift_enabled?

    membership = current_member.current_or_future_membership
    return unless membership&.basket_shift_allowed?

    membership.baskets.detect(&:can_be_member_shifted?)
  end
end
