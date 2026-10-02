# frozen_string_literal: true

module AbsencesHelper
  def absence_creator(creator)
    if creator.is_a?(Admin)
      link_to_if authorized?(:update, creator), creator.name, edit_admin_path(creator)
    else
      auto_link(creator)
    end
  end

  def display_absence?
    feature?("absence") && current_member.current_or_future_membership
  end

  def next_shiftable_basket
    return unless Current.org.basket_shift_enabled?

    current_member.baskets.coming.includes(:membership).detect(&:can_be_member_shifted?)
  end
end
