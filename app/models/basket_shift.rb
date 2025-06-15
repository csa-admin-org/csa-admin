# frozen_string_literal: true

class BasketShift < ApplicationRecord
  include HasDescription

  belongs_to :absence
  belongs_to :source_basket, class_name: "Basket"
  belongs_to :target_basket, class_name: "Basket"

  validate :source_basket_must_be_absent_and_not_empty, on: :create
  validate :target_basket_must_same_membership_and_not_absent, on: :create

  after_validation :set_quantities

  after_create -> {
    decrement_quantities!(source_basket)
    increment_quantities!(target_basket)
  }
  after_destroy -> {
    increment_quantities!(source_basket)
    decrement_quantities!(target_basket)
  }
  after_commit -> { source_basket.membership.touch }

  def self.shiftable?(source, target)
    return unless new(absence: source.absence, source_basket: source, target_basket: target).valid?
    return unless source.basket_size_id == target.basket_size_id

    source.complement_ids & target.complement_ids == source.complement_ids
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

  private

  def set_quantities
    self[:quantities][:basket_size] = { source_basket.basket_size_id => source_basket.quantity }
    self[:quantities][:basket_complements] = source_basket.baskets_basket_complements.map { |bbc|
      [ bbc.basket_complement_id, bbc.quantity ]
    }.to_h
  end

  def source_basket_must_be_absent_and_not_empty
    return unless absence && source_basket

    if absence.baskets.exclude?(source_basket) || source_basket.empty?
      errors.add(:source_basket, :invalid)
    end
  end

  def target_basket_must_same_membership_and_not_absent
    return unless target_basket && source_basket

    if target_basket == source_basket || target_basket.membership_id != source_basket.membership_id || target_basket.absent?
      errors.add(:target_basket, :invalid)
    end
  end

  def increment_quantities!(basket, factor = 1)
    increment_quantity! basket, factor * quantities[:basket_size][basket.basket_size_id].to_i
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
