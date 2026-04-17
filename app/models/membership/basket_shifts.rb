# frozen_string_literal: true

# Handles BasketShift orchestration for a membership.
#
# BasketShifts are delivery-keyed (membership + source_delivery + target_delivery),
# so they survive basket destruction during membership config changes.
#
# When baskets are destroyed and recreated within a range (e.g. basket_size or
# depot change via `sync_baskets_with_config_change!`), shifts must be
# unapplied before destruction and reapplied after recreation. Use
# `with_basket_shifts_reapplied!(range)` to wrap such a block.
#
module Membership::BasketShifts
  extend ActiveSupport::Concern

  included do
    has_many :basket_shifts, dependent: :destroy
  end

  def basket_shift_allowed?
    basket_shifts_allowance_remaining.positive?
  end

  def basket_shifts_allowance_remaining
    return 0 unless Current.org.basket_shift_enabled?
    return Float::INFINITY unless Current.org.basket_shift_annual_limit?

    [ Current.org.basket_shifts_annually - basket_shifts_count, 0 ].max
  end

  def basket_shifts_count
    basket_shifts.count
  end

  private

  # Unapplies shifts touching `range`, yields, then reapplies them.
  # Use around any operation that destroys and recreates baskets in `range`.
  def with_basket_shifts_reapplied!(range)
    unapply_basket_shifts!(range)
    yield
    reapply_basket_shifts!(range)
  end

  def unapply_basket_shifts!(range)
    delivery_ids_in_range = Delivery.between(range).pluck(:id)
    return if delivery_ids_in_range.empty?

    # Shifts where source is in the destroy range — reverse increment on target if target is outside range
    affected_shifts = basket_shifts.where(source_delivery_id: delivery_ids_in_range)

    affected_shifts.each do |shift|
      next if shift.target_delivery_id.in?(delivery_ids_in_range)

      target = shift.target_basket
      next unless target

      shift.unapply_on!(target)
    end

    # Shifts where target is in the destroy range but source is not — reverse decrement on source
    affected_shifts =
      basket_shifts
        .where(target_delivery_id: delivery_ids_in_range)
        .where.not(source_delivery_id: delivery_ids_in_range)

    affected_shifts.each do |shift|
      source = shift.source_basket
      next unless source

      shift.reapply_on!(source)
    end
  end

  def reapply_basket_shifts!(range)
    delivery_ids_in_range = Delivery.between(range).pluck(:id)
    return if delivery_ids_in_range.empty?

    affected_shifts =
      basket_shifts
        .where(source_delivery_id: delivery_ids_in_range)
        .or(basket_shifts.where(target_delivery_id: delivery_ids_in_range))

    affected_shifts.each do |shift|
      source = shift.source_basket
      target = shift.target_basket

      unless source && target && source.absent? && !target.absent?
        Rails.logger.info("[BasketShift] skipping reapply for shift=#{shift.id} " \
          "source_present=#{source.present?} target_present=#{target.present?} " \
          "source_absent=#{source&.absent?} target_absent=#{target&.absent?}")
        next
      end

      # Re-snapshot quantities only if source was also recreated (in range)
      shift.resnapshot! if shift.source_delivery_id.in?(delivery_ids_in_range)

      shift.unapply_on!(source)
      shift.reapply_on!(target)
    end
  end
end
