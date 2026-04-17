# frozen_string_literal: true

class BasketOverride < ApplicationRecord
  include Sessionable

  belongs_to :membership
  belongs_to :delivery

  validates :delivery_id, uniqueness: { scope: :membership_id }
  validate :diff_must_be_present

  before_destroy :revert_basket,
    unless: -> { membership.destroyed? || membership.marked_for_destruction? }

  def self.by_delivery_id(overrides)
    overrides.each_with_object({}) do |override, h|
      key = override.delivery_swap? ? override.diff["override_delivery_id"] : override.delivery_id
      h[key] = override
    end
  end

  def self.compute_diff_from_basket(basket, membership)
    expected = membership.expected_basket_config(basket.delivery)
    adjusted = adjust_for_shifts(basket.config, basket, membership)
    diff = compute_diff(expected, adjusted)
    diff.presence
  end

  def self.compute_diff(expected, actual)
    (expected.keys | actual.keys).each_with_object({}) do |key, diff|
      diff[key] = actual[key] if actual[key] != expected[key]
    end
  end

  def apply_to!(basket)
    attrs = {}

    diff.each do |key, value|
      case key
      when "basket_size_id" then attrs[:basket_size_id] = value if BasketSize.exists?(value)
      when "depot_id"       then attrs[:depot_id] = value if Depot.exists?(value)
      when "override_delivery_id"
        # The target delivery may already have a basket (recreated by config
        # sync). Destroy it so the swap can be reapplied.
        existing = membership.baskets.find_by(delivery_id: value)
        existing.destroy! if existing && existing != basket
        attrs[:delivery_id] = value
      when "complements" then nil
      else attrs[key.to_sym] = value
      end
    end

    basket.update!(attrs) if attrs.any?
    replace_complements!(basket, diff["complements"]) if diff.key?("complements")

    destroy! if !delivery_swap? && effectively_empty_after_apply?(basket)
  end

  def active?
    expected = membership.expected_basket_config(delivery)
    diff.any? { |key, value| expected[key] != value }
  end

  def delivery_swap?
    diff.key?("override_delivery_id")
  end

  # Subtract shift-induced quantity adjustments so they don't produce
  # spurious overrides. Returns adjusted copy or original if no shifts.
  def self.adjust_for_shifts(actual, basket, membership)
    basket_qty_adj = 0
    complement_qty_adjs = Hash.new(0)

    shifts = BasketShift
      .where(membership: membership)
      .where("source_delivery_id = :id OR target_delivery_id = :id", id: basket.delivery_id)

    shifts.each do |shift|
      sign = shift.target_delivery_id == basket.delivery_id ? 1 : -1
      basket_qty_adj += sign * shift.quantities[:basket_size]&.values&.first.to_i
      shift.quantities[:basket_complements]&.each { |id, qty| complement_qty_adjs[id] += sign * qty }
    end

    return actual if basket_qty_adj.zero? && complement_qty_adjs.empty?

    adjusted = actual.dup
    adjusted["quantity"] -= basket_qty_adj if basket_qty_adj != 0
    if complement_qty_adjs.any?
      adjusted["complements"] = adjusted["complements"].map { |c|
        adj = complement_qty_adjs[c["basket_complement_id"]] || 0
        adj.zero? ? c : c.merge("quantity" => c["quantity"] - adj)
      }
    end
    adjusted
  end
  private_class_method :adjust_for_shifts

  private

  def revert_basket
    if delivery_swap?
      swapped = membership.baskets.find_by(delivery_id: diff["override_delivery_id"])
      return unless swapped

      swapped.destroy!
      membership.create_basket!(delivery)
    else
      basket = membership.baskets.find_by(delivery_id: delivery_id)
      return unless basket

      expected = membership.expected_basket_config(delivery)
      return if self.class.compute_diff(expected, basket.config).empty?

      assign_config_to!(basket, expected)
    end
  end

  def assign_config_to!(basket, config)
    basket.update!(config.except("complements").transform_keys(&:to_sym))
    replace_complements!(basket, config["complements"])
  end

  def replace_complements!(basket, complements)
    basket.baskets_basket_complements.destroy_all
    complements.each do |comp|
      next unless BasketComplement.exists?(comp["basket_complement_id"])

      basket.baskets_basket_complements.create!(
        basket_complement_id: comp["basket_complement_id"],
        quantity: comp["quantity"],
        price: comp["price"])
    end
  end

  def diff_must_be_present
    errors.add(:base, :blank) if diff.blank?
  end

  # Reload is required: apply_to! has just mutated the basket (and its
  # complements) via update!, so the in-memory copy is stale.
  def effectively_empty_after_apply?(basket)
    self.class.compute_diff(
      membership.expected_basket_config(basket.delivery),
      basket.reload.config
    ).empty?
  end
end
