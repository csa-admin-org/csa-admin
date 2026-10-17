# frozen_string_literal: true

class BasketShift < ApplicationRecord
  include HasDescription

  belongs_to :absence
  belongs_to :membership
  belongs_to :source_delivery, class_name: "Delivery"
  belongs_to :target_delivery, class_name: "Delivery"

  validates :source_delivery_id, uniqueness: { scope: :membership_id }

  validate :source_basket_must_be_absent_and_not_empty, on: :create
  validate :target_basket_must_same_membership_and_not_absent, on: :create

  after_validation :set_quantities, on: :create

  after_create -> {
    decrement_quantities!(source_basket) if source_basket
    increment_quantities!(target_basket) if target_basket
  }
  after_destroy -> {
    increment_quantities!(source_basket) if source_basket
    decrement_quantities!(target_basket) if target_basket
  }
  after_destroy :cleanup_shift!
  after_commit -> { membership.touch if membership.persisted? }
  after_commit -> { MailTemplate.deliver(:absence_baskets_shifted, absence: absence) }, on: :create

  def self.shiftable?(source, target)
    return false unless source && target
    return false if source.shifted?
    return false if source.absence && source.empty?

    source.admin_shift_target?(target)
  end

  def source_basket
    @source_basket ||= membership.baskets.find_by(delivery_id: source_delivery_id)
  end

  def target_basket
    @target_basket ||= membership.baskets.find_by(delivery_id: target_delivery_id)
  end

  def quantities
    super.deep_transform_keys { |k| k.to_s =~ /\A\d+\z/ ? k.to_i : k.to_sym }
  end

  def description(public_name: false)
    [
      basket_description(public_name: public_name),
      complements_description(public_name: public_name)
    ].compact.join(" + ").presence || "–"
  end

  def basket_description(public_name: false)
    id, qty = quantities[:basket_size].first
    describe(BasketSize.find(id), qty, public_name: public_name)
  end

  def complements_description(public_name: false)
    complements = quantities[:basket_complements]
    return if complements.blank?

    by_id = BasketComplement.where(id: complements.map(&:first)).index_by(&:id)
    complements.filter_map { |id, quantity|
      describe(by_id[id], quantity, public_name: public_name) if by_id[id]
    }.to_sentence.presence
  end

  # Reverses the effect of this shift on a basket outside the recreate range.
  # Called by Membership#unapply_basket_shifts! before baskets are destroyed.
  def unapply_on!(basket)
    decrement_quantities!(basket)
  end

  # Re-applies the effect of this shift on a basket after recreation.
  # Called by Membership#reapply_basket_shifts! after baskets are recreated.
  def reapply_on!(basket)
    increment_quantities!(basket)
  end

  # Re-snapshots quantities from the current source basket and saves.
  # Called when the source basket was recreated (e.g. basket_size change).
  def resnapshot!
    @source_basket = nil
    set_quantities
    save!
  end

  private

  def cleanup_shift!
    remove_shift_receptacle!
    remove_generated_absence!
  end

  def remove_shift_receptacle!
    basket = target_basket
    return unless basket
    return if BasketShift.where(membership_id: membership_id, target_delivery_id: target_delivery_id).where.not(id: id).exists?
    return if membership.delivery_cycle.include_delivery?(basket.delivery)

    basket.reload
    return unless basket.quantity.to_i.zero?
    return if basket.baskets_basket_complements.sum(:quantity).positive?

    basket.destroy!
  end

  # A one-day absence created with this shift has nothing left to cover.
  # A longer absence, or one the member declared earlier, stays.
  def remove_generated_absence!
    record = absence
    return unless record&.started_on == record.ended_on
    return if record.basket_shifts.exists?
    return if (record.created_at - created_at).abs > 1.minute

    record.destroy!
  end

  def set_quantities
    basket = source_basket
    return unless basket

    self[:quantities] = {
      basket_size: { basket.basket_size_id => basket.quantity },
      basket_complements: basket.baskets_basket_complements.map { |bbc|
        [ bbc.basket_complement_id, bbc.quantity ]
      }.to_h
    }
  end

  def source_basket_must_be_absent_and_not_empty
    return unless absence

    basket = source_basket
    if basket.nil? || absence.baskets.exclude?(basket) || basket.empty?
      errors.add(:source_delivery, :invalid)
    end
  end

  def target_basket_must_same_membership_and_not_absent
    basket = source_basket
    target = target_basket

    if target.nil? || basket.nil? || target == basket || target.membership_id != membership_id || target.absent?
      errors.add(:target_delivery, :invalid)
    end
  end

  def increment_quantities!(basket, factor = 1)
    basket_qty = quantities[:basket_size]&.values&.first.to_i
    increment_quantity! basket, factor * basket_qty
    bb_complements = basket.baskets_basket_complements.to_a
    quantities[:basket_complements].each do |id, quantity|
      bbc = bb_complements.find { |row| row.basket_complement_id == id }
      bbc ||= build_shift_complement!(basket, id) if factor.positive?
      increment_quantity! bbc, factor * quantity
    end
  end

  # A new date has no complement rows. Build one only when that delivery includes it.
  def build_shift_complement!(basket, complement_id)
    complement = BasketComplement.find(complement_id)
    return unless basket.delivery_id.in?(complement.current_and_future_delivery_ids)

    source = source_basket&.baskets_basket_complements&.detect { |row|
      row.basket_complement_id == complement_id
    }
    basket.baskets_basket_complements.create!(
      basket_complement_id: complement_id,
      quantity: 0,
      price: source&.price || complement.price)
  end

  def decrement_quantities!(basket)
    increment_quantities!(basket, -1)
  end

  def increment_quantity!(item, by)
    return unless item

    if by.negative?
      by = [ -item.quantity, by ].max
    end
    item.increment!(:quantity, by)
  end
end
