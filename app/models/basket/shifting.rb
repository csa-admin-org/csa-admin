# frozen_string_literal: true

module Basket::Shifting
  extend ActiveSupport::Concern

  included do
    has_one :shift_as_source,
      ->(basket) { where(membership_id: basket.membership_id) },
      class_name: "BasketShift",
      foreign_key: :source_delivery_id,
      primary_key: :delivery_id,
      dependent: nil

    has_many :shifts_as_target,
      ->(basket) { where(membership_id: basket.membership_id) },
      class_name: "BasketShift",
      foreign_key: :target_delivery_id,
      primary_key: :delivery_id,
      dependent: nil
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
    shift_declined? ? "declined" : shift_as_source&.target_basket&.id
  end

  def shift_target_basket_id=(id)
    if id == "declined"
      self.shift_declined_at ||= Time.current
    elsif id.blank?
      self.shift_declined_at = nil
    else
      target = membership.baskets.find(id)
      self.build_shift_as_source(
        absence: absence,
        membership: membership,
        target_delivery: target.delivery)
      self.shift_declined_at = nil
    end
  end
end
