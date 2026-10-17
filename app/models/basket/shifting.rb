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
    absent? && absence_id? && !empty? && !shifted? && (billable? || Current.org.absences_billed?)
  end

  def can_only_be_shifted?
    !billable? && can_be_shifted?
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
    return false unless member_shift_open?
    return false unless absence_id? || member_direct_shift?

    member_shiftable_basket_targets.any? || member_off_cycle_shift_deliveries.any?
  end

  # The next delivery still outside the absence notice, and the one after it.
  # Later dates wait for an absence, then use the same shift.
  def member_direct_shift?
    return false unless member_shift_open?
    return false if absent? || !Current.org.within_absence_notice_period?(delivery.date)

    open = membership.baskets.coming.not_absent.reject(&:shifted?)
    open.first(2).include?(self)
  end

  # Admin one-step: create the absence if needed, then shift.
  # `can_be_shifted?` stays the post-absence check used by the edit form.
  def can_be_admin_shifted?
    admin_shift_block_reason.nil?
  end

  def admin_shift_block_reason
    return :empty if content_empty?
    return :past_membership unless membership.can_update?
    return :already_shifted if shifted?
    return :received_shift if received_shift?
    return :forced if forced?
    return :absences_not_billed unless Current.org.absences_billed?
    return :no_targets unless shift_candidates.any? { |target| admin_shift_target?(target) } || admin_off_cycle_shift_deliveries.any?

    nil
  end

  def admin_shift_target?(target)
    return false if target.id == id || target.membership_id != membership_id
    return false if target.absent? || target.received_shift?
    return true if shift_receptacle?(target)
    return false unless basket_size_id == target.basket_size_id
    return false unless same_complements?(target)

    true
  end

  # Empty basket created so a shift can land on a date this membership does not already have.
  def shift_receptacle?(target = self)
    return false unless target.quantity.to_i.zero?
    return false unless target.membership_id == membership_id
    return false if target.absent? || target.received_shift?

    complements = target.baskets_basket_complements
    return false if complements.loaded? ? complements.any? : complements.exists?

    true
  end

  def received_shift?
    delivery_id.in?(received_shift_delivery_ids)
  end

  def ensure_definite_absence!(admin: nil)
    return self if absence_id?

    date = delivery.date
    member.absences.including_date(date).first ||
      member.absences.create!(
        started_on: date,
        ended_on: date,
        admin: admin,
        skip_notice_period: admin.nil?,
        session: Current.session)
    membership.touch
    reload
    self
  end

  def member_shiftable_basket_targets
    return @member_shiftable_basket_targets if defined?(@member_shiftable_basket_targets)
    return [] unless membership.basket_shift_allowed?
    return [] unless can_be_shifted? || (!absent? && member_direct_shift?)

    candidates = member_shift_candidates
    if range_allowed = member_shift_allowed_range
      candidates = candidates.select { |target| target.delivery.date.in?(range_allowed) }
    end
    @member_shiftable_basket_targets = candidates.select { |target|
      admin_shift_target?(target)
    }
  end

  # Unused deliveries the depot still serves, off this membership's cycle.
  # Same window as a shift onto a basket they already have: the deadline in
  # weeks, or any date in the membership when that deadline is blank.
  def member_off_cycle_shift_deliveries
    return @member_off_cycle_shift_deliveries if defined?(@member_off_cycle_shift_deliveries)
    return [] unless absence_id? || (!absent? && member_direct_shift?)
    return [] unless member_shift_open?

    window = member_shift_allowed_range || (Date.tomorrow..membership.ended_on)
    occupied_ids = membership.baskets.pluck(:delivery_id)
    cycle = membership.delivery_cycle

    @member_off_cycle_shift_deliveries =
      Delivery.between(window).where.not(id: occupied_ids).select { |candidate|
        candidate.date != delivery.date &&
          !cycle.include_delivery?(candidate) &&
          depot_serves_delivery?(candidate) &&
          !member_overlay_covers?(candidate) &&
          member.absences.including_date(candidate.date).none?
      }
  end

  # Admin has no deadline. Same dates the delivery dropdown used to list.
  def admin_off_cycle_shift_deliveries
    occupied_ids = membership.baskets.pluck(:delivery_id) - [ delivery_id ]
    cycle = membership.delivery_cycle

    Delivery.between(membership.period).where.not(id: occupied_ids).select { |candidate|
      candidate.id != delivery_id &&
        !cycle.include_delivery?(candidate) &&
        depot_serves_delivery?(candidate)
    }
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

  private

  def shift_candidates
    cache = membership.instance_variable_get(:@admin_shift_candidates)
    return cache if cache

    records = membership.baskets.includes(:delivery, :baskets_basket_complements).to_a
    membership.instance_variable_set(:@admin_shift_candidates, records)
  end

  def member_shift_candidates
    cache = membership.instance_variable_get(:@member_shift_candidates)
    return cache if cache

    records = membership.baskets.coming.includes(:delivery, :baskets_basket_complements).to_a
    membership.instance_variable_set(:@member_shift_candidates, records)
  end

  def member_shift_allowed_range
    return @member_shift_allowed_range if defined?(@member_shift_allowed_range)

    @member_shift_allowed_range =
      Current.org.basket_shift_allowed_range_for(self) || direct_shift_deadline_range
  end

  def direct_shift_deadline_range
    return unless member_direct_shift? && Current.org.basket_shift_deadline_enabled?

    weeks = Current.org.basket_shift_deadline_in_weeks.weeks
    ([ delivery.date - weeks, Date.tomorrow ].max)..(delivery.date + weeks)
  end

  def member_shift_open?
    return false unless Current.org.basket_shift_enabled?
    return false unless membership.can_update? && membership.basket_shift_allowed?
    return false if shifted? || received_shift? || content_empty? || forced?
    return false if member_overlay_covers?(delivery)

    true
  end

  def depot_serves_delivery?(candidate)
    depot.include_delivery?(candidate) ||
      Basket.where(depot_id: depot_id, delivery_id: candidate.id).exists?
  end

  def member_overlay_covers?(candidate)
    return false unless depot.delivery_sheets_mode == "home_delivery"

    HomeDeliveryAddress.for(member, candidate).present?
  end

  def same_complements?(target)
    ids = complement_ids_for(self)
    ids & complement_ids_for(target) == ids
  end

  def complement_ids_for(basket)
    cache = basket.instance_variable_get(:@shift_complement_ids)
    return cache if cache

    bbc = basket.baskets_basket_complements
    ids = if bbc.loaded?
      bbc.map(&:basket_complement_id)
    else
      bbc.pluck(:basket_complement_id)
    end
    basket.instance_variable_set(:@shift_complement_ids, ids)
  end

  def received_shift_delivery_ids
    cache = membership.instance_variable_get(:@received_shift_delivery_ids)
    return cache if cache

    ids = BasketShift.where(membership_id: membership_id).distinct.pluck(:target_delivery_id)
    membership.instance_variable_set(:@received_shift_delivery_ids, ids)
  end

  def content_empty?
    complements = baskets_basket_complements
    extra = if complements.loaded?
      complements.sum { |bbc| bbc.quantity.to_i }
    else
      complements.sum(:quantity)
    end
    (quantity.to_i + extra).zero?
  end
end
