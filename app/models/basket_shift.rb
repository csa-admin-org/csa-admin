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
  after_commit -> { membership.touch if membership.persisted? }
  after_commit -> { MailTemplate.deliver(:absence_baskets_shifted, absence: absence) }, on: :create

  def self.shiftable?(source, target)
    shift = new(
      absence: source.absence,
      membership: source.membership,
      source_delivery: source.delivery,
      target_delivery: target.delivery)
    return unless shift.valid?
    return unless source.basket_size_id == target.basket_size_id

    source.complement_ids & target.complement_ids == source.complement_ids
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
    quantities[:basket_complements].map { |id, quantity|
      describe(BasketComplement.find(id), quantity, public_name: public_name)
    }.compact.to_sentence.presence
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
      bbc = bb_complements.find { |bbc| bbc.basket_complement_id == id }
      increment_quantity! bbc, factor * quantity
    end
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
