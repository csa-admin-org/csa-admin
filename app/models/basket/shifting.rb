# frozen_string_literal: true

module Basket::Shifting
  extend ActiveSupport::Concern

  included do
    has_one :shift_as_source,
      class_name: "BasketShift",
      inverse_of: :source_basket,
      dependent: :destroy
    has_many :shifts_as_target,
      class_name: "BasketShift",
      inverse_of: :target_basket,
      dependent: :destroy
  end

  def can_be_shifted?
    absent? && !empty? && !shifted? && billable?
  end

  # Not billable (absences_included quota) or empty means content won't be received.
  def content_forfeited?
    absent? && (!billable? || empty?)
  end

  def shifted?
    shift_as_source.present?
  end

  def shift_declined?
    shift_declined_at?
  end

  def can_be_member_shifted?
    can_be_shifted? && member_shiftable_basket_targets.any?
  end

  def member_shiftable_basket_targets
    return [] unless can_be_shifted?
    return [] unless membership.basket_shift_allowed?

    baskets = membership.baskets.coming.includes(:delivery)
    if range_allowed = Current.org.basket_shift_allowed_range_for(self)
      baskets = baskets.between(range_allowed)
    end
    baskets.select { |target| BasketShift.shiftable?(self, target) }
  end

  def shift_target_basket_id
    shift_declined? ? "declined" : shift_as_source&.target_basket_id
  end

  def shift_target_basket_id=(id)
    if id == "declined"
      self.shift_declined_at ||= Time.current
    elsif id.blank?
      self.shift_declined_at = nil
    else
      self.build_shift_as_source(
        absence: absence,
        target_basket_id: id)
      self.shift_declined_at = nil
    end
  end
end
