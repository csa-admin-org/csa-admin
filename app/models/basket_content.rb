# frozen_string_literal: true

class BasketContent < ApplicationRecord
  UNITS = %w[kg pc]

  include Form

  belongs_to :delivery
  belongs_to :product, class_name: "BasketContent::Product"
  has_and_belongs_to_many :depots

  scope :basket_size_eq, ->(id) {
    where("EXISTS (SELECT 1 FROM json_each(basket_quantities) WHERE json_each.key = CAST(? AS TEXT))", id.to_i)
  }
  scope :with_positive_quantity_for, ->(basket_size_id) {
    where("json_extract(basket_quantities, '$.' || CAST(? AS TEXT)) > 0", basket_size_id.to_i)
  }
  scope :for_depot, ->(depot) {
    joins(:depots).where(basket_contents_depots: { depot_id: depot })
  }
  scope :with_unit_price, -> { where.not(unit_price: nil) }
  scope :in_kg, -> { where(unit: "kg") }
  scope :in_pc, -> { where(unit: "pc") }
  scope :during_year, ->(year) {
    joins(:delivery)
      .where(deliveries: { date: Current.org.fiscal_year_for(year).range })
  }

  validates :delivery, presence: true
  validates :unit, inclusion: { in: UNITS }, presence: true
  validate :basket_quantities_structure
  validate :depots_presence
  validates :unit_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  before_validation :set_unit_from_product
  after_commit :update_delivery_basket_content_avg_prices!
  after_commit :sync_product_latest_basket_content!

  def self.duplicate_all(from_delivery_id, to_delivery_id)
    contents = where(delivery_id: from_delivery_id)
    return if contents.none?

    existing_product_ids = where(delivery_id: to_delivery_id).distinct.pluck(:product_id)
    contents = contents.where.not(product_id: existing_product_ids) if existing_product_ids.any?
    return if contents.none?

    transaction do
      contents.includes(:depots).find_each do |content|
        create!(
          product_id: content.product_id,
          unit: content.unit,
          unit_price: content.unit_price,
          delivery_id: to_delivery_id,
          basket_quantities: content.basket_quantities,
          depot_ids: content.depot_ids)
      end
    end
  end

  def self.filled_deliveries
    ids = distinct.pluck(:delivery_id)
    Delivery.where(id: ids).reorder(date: :desc)
  end

  def self.coming_deliveries_missing_contents_from(delivery, after_date: delivery.date)
    delivery_id = delivery.id
    source_product_ids = where(delivery_id: delivery_id).distinct.pluck(:product_id)
    return Delivery.none if source_product_ids.empty?

    delivery_ids = Delivery.where(date: after_date..).where.not(id: delivery_id).pluck(:id)
    delivery_ids.select! { |target_delivery_id|
      where(delivery_id: target_delivery_id, product_id: source_product_ids).distinct.count(:product_id) < source_product_ids.size
    }
    Delivery.where(id: delivery_ids)
  end

  def self.filled_deliveries_with_contents_missing_from(delivery)
    delivery_id = delivery.id
    target_product_ids = where(delivery_id: delivery_id).distinct.pluck(:product_id)
    delivery_ids = where.not(delivery_id: delivery_id).distinct.pluck(:delivery_id)
    if target_product_ids.any?
      delivery_ids.select! { |source_delivery_id|
        where(delivery_id: source_delivery_id).where.not(product_id: target_product_ids).exists?
      }
    end
    Delivery.where(id: delivery_ids).reorder(date: :desc)
  end

  def self.closest_delivery(year = nil)
    scope = Delivery.joins(:basket_contents)
    scope = scope.during_year(year) if year
    scope
      .distinct
      .reorder(Arel.sql("ABS(julianday(deliveries.date) - julianday(date('now')))"))
      .first
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i[basket_size_eq during_year]
  end

  # --- Quantity accessors (computed from basket_quantities hash) ---

  def basket_size_ids
    (basket_quantities || {}).keys.map(&:to_i)
  end

  def basket_sizes
    @basket_sizes ||= BasketSize.reorder(:id).where(id: basket_size_ids)
  end

  def basket_quantity(basket_size)
    id = basket_size.respond_to?(:id) ? basket_size.id : basket_size
    (basket_quantities || {})[id.to_s]&.to_f || 0
  end

  def basket_size_ids_quantity(basket_size)
    qty = basket_quantity(basket_size)
    case unit
    when "kg" then basket_quantity_in_grams(basket_size)
    when "pc" then qty.to_i
    end
  end

  def baskets_count(basket_size)
    id = basket_size.respond_to?(:id) ? basket_size.id : basket_size
    baskets_counts_hash[id.to_i] || 0
  end

  # Allow external preloading of basket counts to avoid N+1 queries
  # (e.g. in XLSX export where all contents share the same delivery)
  def baskets_counts_hash=(hash)
    @baskets_counts_hash = hash
  end

  def unit
    self[:unit] || product&.unit
  end

  def quantity
    exact_quantity.round(3)
  end

  def exact_quantity
    case unit
    when "kg" then exact_quantity_in_grams / 1000.0
    else basket_size_ids.sum { |id| basket_quantity(id) * baskets_count(id) }
    end
  end

  def ceiled_total_quantity
    case unit
    when "kg"
      grams = exact_quantity_in_grams
      return 0 unless grams.positive?

      (grams / 1000.0).ceil
    when "pc"
      quantity = exact_quantity
      return 0 unless quantity.positive?

      round_pieces_quantity(quantity)
    else
      0
    end
  end

  def quantity_surplus
    case unit
    when "kg"
      grams = exact_quantity_in_grams
      return 0 unless grams.positive?

      [ ceiled_total_quantity * 1000 - grams, 0 ].max
    when "pc"
      surplus = ceiled_total_quantity - exact_quantity
      [ surplus.round, 0 ].max
    else
      0
    end
  end

  def quantity_surplus_unit
    unit == "kg" ? "g" : unit
  end

  def basket_percentage(basket_size)
    quantities = basket_size_ids.map { |id| basket_quantity(id) }
    total = quantities.sum
    return 0 if total.zero?

    id = basket_size.respond_to?(:id) ? basket_size.id : basket_size
    qty = basket_quantity(id)
    (qty / total * 100).round
  end

  def basket_size_ids_quantities
    basket_size_ids.map { |bs| [ bs, basket_size_ids_quantity(bs) ] }.to_h
  end

  def basket_size_ids_percentages
    basket_size_ids.map { |bs| [ bs, basket_percentage(bs) ] }.to_h
  end

  def basket_size_ids_percentages_pro_rated
    pcts = basket_percentages_pro_rated
    default_basket_sizes.map.with_index { |bs, i| [ bs.id, pcts[i] ] }.to_h
  end

  def basket_size_ids_percentages_even
    pcts = basket_percentages_even
    default_basket_sizes.map.with_index { |bs, i| [ bs.id, pcts[i] ] }.to_h
  end

  def basket_size_ids_quantities=(quantities)
    effective_unit = product&.unit || unit
    self.basket_quantities = (quantities || {}).each_with_object({}) do |(id, val), h|
      quantity = numeric_quantity(val)
      next if quantity.nil? || quantity.zero?

      h[id.to_s] = case effective_unit
      when "kg" then quantity / 1000.0
      when "pc" then quantity.to_i
      end
    end
  end

  def price_for(basket_size, depot)
    return unless depots.include?(depot)

    basket_quantity(basket_size).to_f * unit_price
  end

  def can_update?
    delivery.date >= 6.months.ago
  end

  def can_destroy?
    delivery.date >= 6.months.ago
  end

  private

  def basket_quantity_in_grams(basket_size)
    (BigDecimal(basket_quantity(basket_size).to_s) * 1000).round
  end

  def exact_quantity_in_grams
    basket_size_ids.sum { |id| basket_quantity_in_grams(id) * baskets_count(id) }
  end

  def round_pieces_quantity(quantity)
    quantity = quantity.ceil
    return quantity if quantity < 10

    (quantity / 10.0).ceil * 10
  end

  def baskets_counts_hash
    @baskets_counts_hash ||=
      if delivery
        delivery.baskets.active
          .where(depot_id: depot_ids)
          .group(:basket_size_id)
          .sum(:quantity)
      else
        {}
      end
  end

  def default_basket_sizes
    @default_basket_sizes ||= BasketSize.paid.reorder(:id)
  end

  def basket_percentages_pro_rated
    total_prices = default_basket_sizes.sum(&:price)
    pcts = default_basket_sizes.map do |bs|
      ((bs.price / total_prices.to_f) * 100).round
    end
    ensure_100(pcts)
  end

  def basket_percentages_even
    pcts = default_basket_sizes.map do
      (100 / default_basket_sizes.length.to_f).round
    end
    ensure_100(pcts)
  end

  def ensure_100(pcts)
    return pcts if pcts.empty?

    until pcts.sum == 100
      if pcts.sum < 100
        pcts[default_basket_sizes.index(BasketSize.order(:price).paid.last)] += 1
      else
        pcts[default_basket_sizes.index(BasketSize.order(:price).paid.first)] -= 1
      end
    end
    pcts
  end

  def basket_quantities_structure
    return if basket_quantities.blank?

    errors.add(:basket_quantities, :invalid) unless basket_quantity_ids_valid? && basket_quantity_values_valid?
  end

  def basket_quantity_ids_valid?
    ids = basket_quantities.keys.map { |id| Integer(id, exception: false) }
    ids.all? && ids.uniq.size == ids.size && BasketSize.paid.where(id: ids).count == ids.size
  end

  def basket_quantity_values_valid?
    basket_quantities.values.all? { |value| numeric_quantity(value)&.positive? }
  end

  def numeric_quantity(value)
    Float(value, exception: false)
  end

  def depots_presence
    # Reload association to prevent stale cache issues that can cause random
    # "depots cannot be empty" errors in production server instances
    depots.reload if persisted? && depots.loaded?
    errors.add(:depots, :blank) if depots.empty?
  end

  def update_delivery_basket_content_avg_prices!
    delivery.update_basket_content_avg_prices!
  end

  def sync_product_latest_basket_content!
    product.sync_latest_basket_content!
  end

  def set_unit_from_product
    self.unit = product.unit if product
  end
end
