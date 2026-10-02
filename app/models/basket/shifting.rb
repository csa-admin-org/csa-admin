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
    can_be_shifted? && member_shiftable_basket_targets.any?
  end

  # Admin one-step: create the absence if needed, then shift.
  # `can_be_shifted?` stays the post-absence check used by the edit form.
  def can_be_admin_shifted?
    admin_shift_block_reason.nil?
  end

  def admin_shift_block_reason
    return :past_membership unless membership.can_update?
    return :already_shifted if shifted?
    return :received_shift if received_shift?
    return :empty if content_empty?
    return :forced if forced?
    return :absences_not_billed unless Current.org.absences_billed?
    return :no_targets unless admin_shift_targets?

    nil
  end

  def admin_shift_targets?
    shift_candidates.any? { |target| admin_shift_target?(target) }
  end

  def admin_shift_target?(target)
    return false if target.id == id || target.membership_id != membership_id
    return false if target.absent? || target.received_shift?
    return false unless basket_size_id == target.basket_size_id
    return false unless same_complements?(target)

    true
  end

  def received_shift?
    delivery_id.in?(received_shift_delivery_ids)
  end

  def ensure_definite_absence!(admin:)
    return self if absence_id?

    date = delivery.date
    member.absences.including_date(date).first ||
      member.absences.create!(
        started_on: date,
        ended_on: date,
        admin: admin,
        session: Current.session)
    membership.touch
    reload
    self
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

  private

  def shift_candidates
    cache = membership.instance_variable_get(:@admin_shift_candidates)
    return cache if cache

    records = membership.baskets.includes(:delivery, :baskets_basket_complements).to_a
    membership.instance_variable_set(:@admin_shift_candidates, records)
  end

  def same_complements?(target)
    ids = complement_ids
    ids & target.complement_ids == ids
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
