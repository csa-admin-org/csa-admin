class BasketContent < ApplicationRecord
  UNITS = %w[kg pc]
  DISTRIBUTION_MODES = %w[automatic manual]

  include BasketContentsHelper

  attribute :distribution_mode, :string, default: -> { last&.distribution_mode }

  belongs_to :delivery
  belongs_to :product, class_name: "BasketContent::Product"
  has_and_belongs_to_many :depots

  scope :basket_size_eq, ->(id) { where("basket_size_ids @> ?", "{#{id}}") }
  scope :for_depot, ->(depot) {
    joins(:depots).where("basket_contents_depots.depot_id = ?", depot)
  }
  scope :with_unit_price, -> { where.not(unit_price: nil) }
  scope :in_kg, -> { where(unit: "kg") }
  scope :in_pc, -> { where(unit: "pc") }
  scope :during_year, ->(year) {
    joins(:delivery)
      .where(deliveries: { date: Current.acp.fiscal_year_for(year).range })
  }

  after_initialize :set_defaults

  before_validation :set_distribution_mode, :set_basket_quantities

  validates :delivery, presence: true
  validates :quantity, presence: true
  validates :depots, presence: true
  validates :unit, inclusion: { in: UNITS }, presence: true
  validates :distribution_mode, inclusion: { in: DISTRIBUTION_MODES }
  validate :basket_size_ids_presence
  validate :basket_percentages_presence
  validate :basket_quantities_presence
  validate :enough_quantity
  validates :unit_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  after_commit :update_delivery_basket_content_avg_prices!

  def self.duplicate_all(from_delivery_id, to_delivery_id)
    contents = where(delivery_id: from_delivery_id)
    return if contents.none?
    return if where(delivery_id: to_delivery_id).any?

    transaction do
      contents.includes(:depots).find_each do |content|
        attrs = content.attributes.slice(*%w[
            product_id
            quantity
            unit
            unit_price
          ]).merge(
            delivery_id: to_delivery_id,
            depot_ids: content.depot_ids,
            basket_size_ids_percentages: content.basket_size_ids_percentages,
            basket_size_ids_quantities: content.basket_size_ids_quantities)
        create(attrs)
      end
    end
  end

  def self.filled_deliveries
    ids = distinct.pluck(:delivery_id)
    Delivery.where(id: ids).reorder(date: :desc)
  end

  def self.coming_unfilled_deliveries(after_date:)
    ids = distinct.pluck(:delivery_id)
    Delivery.where.not(id: ids).where(date: after_date..)
  end

  def self.next_delivery
    all.joins(:delivery).order(:date).first&.delivery
  end

  def self.last_delivery
    all.joins(:delivery).order(:date).last&.delivery
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i[basket_size_eq during_year]
  end

  def distribution_automatic?
    distribution_mode == "automatic"
  end

  def distribution_manual?
    distribution_mode == "manual"
  end

  def basket_size_ids_quantities
    return {} if distribution_mode == "automatic"

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

  def basket_size_ids_percentages=(percentages)
    @percentages = percentages
  end

  def basket_size_ids_quantities=(quantities)
    @quantities = quantities
  end

  def basket_sizes
    @basket_sizes ||= BasketSize.reorder(:id).find(basket_size_ids)
  end

  def basket_percentage(basket_size)
    i =
      case distribution_mode
      when "automatic"; basket_size_index(basket_size)
      when "manual"; default_basket_size_index(basket_size)
      end
    (i && basket_percentages[i]) || 0
  end

  def baskets_count(basket_size)
    if i = basket_size_index(basket_size)
      baskets_counts[i]
    end
  end

  def basket_quantity(basket_size)
    if i = basket_size_index(basket_size)
      basket_quantities[i]
    end
  end

  def basket_size_ids_quantity(basket_size)
    return unless distribution_manual?

    quantity = basket_quantity(basket_size)
    case unit
    when "kg"; (quantity.to_f * 1000).to_i
    when "pc"; quantity.to_i
    else
      0
    end
  end

  def price_for(basket_size, depot)
    return unless depots.include?(depot)

    basket_quantity(basket_size).to_f * unit_price
  end

  private

  def set_defaults
    return unless basket_size_ids.empty?

    self[:basket_size_ids] = default_basket_sizes.map(&:id)
    self[:basket_percentages] = basket_percentages_pro_rated
    self[:basket_quantities] = []
    self[:surplus_quantity] = nil
    @percentages ||= {}
    @quantities ||= {}
  end

  def default_basket_sizes
    @default_basket_size ||= BasketSize.paid.reorder(:id)
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
        pcts[default_basket_sizes.index(BasketSize.paid.last)] += 1
      else
        pcts[default_basket_sizes.index(BasketSize.paid.first)] -= 1
      end
    end
    pcts
  end

  def basket_size_index(basket_size)
    id = basket_size.respond_to?(:id) ? basket_size.id : basket_size
    basket_size_ids.index(id)
  end

  def default_basket_size_index(basket_size)
    id = basket_size.respond_to?(:id) ? basket_size.id : basket_size
    default_basket_sizes.map(&:id).index(id)
  end

  def basket_size_ids_presence
    if basket_size_ids.empty?
      errors.add(:basket_size_ids, :blank)
    end
  end

  def basket_percentages_presence
    return unless distribution_automatic?

    if basket_size_ids.size != basket_percentages.size || basket_percentages.sum != 100
      errors.add(:basket_percentages, :invalid)
    end
  end

  def basket_quantities_presence
    return unless distribution_manual?

    if basket_size_ids.size != basket_quantities.size || basket_quantities.sum.zero?
      errors.add(:basket_quantities, :invalid)
    end
  end

  def enough_quantity
    if basket_quantities.empty?
      errors.add(:quantity, :insufficient)
    elsif surplus_quantity < 0
      errors.add(:quantity, :insufficient_miss,
        miss: display_quantity(surplus_quantity.abs, unit))
    end
  end

  def set_baskets_counts
    return unless delivery

    self[:baskets_counts] = []
    baskets = delivery.baskets.not_absent.where(depot_id: depot_ids)
    basket_size_ids.each do |id|
      self[:baskets_counts] << baskets.where(basket_size_id: id).sum(:quantity)
    end
  end

  def set_distribution_mode
    self.distribution_mode =
      @quantities.values.any?(&:present?) ? "manual" : "automatic"
  end

  def set_basket_quantities
    return unless quantity

    case distribution_mode
    when "automatic"; set_basket_quantities_automatically
    when "manual"; set_basket_quantities_manually
    end

    self[:surplus_quantity] = quantity - total_quantities(basket_quantities)
  end

  def set_basket_quantities_automatically
    non_zero_pcts = @percentages.compact.reject { |_, p| p.to_i.zero? }
    self[:basket_size_ids] = non_zero_pcts.keys
    self[:basket_percentages] = non_zero_pcts.values.map(&:to_i)
    set_baskets_counts

    roundings = %i[up upup down downdown]
    permutations = roundings.repeated_permutation(basket_size_ids.size)
    possibilities = permutations.map { |r| possibility(r) }
    possibilities.reject! { |p|
      p.any?(&:negative?) ||
      p.map.with_index { |q, i|
        count = baskets_counts[i]
        (q.zero? && count.positive?) || (q.positive? && count.zero?)
      }.any? ||
      total_quantities(p) > quantity
    }
    if best_possibility = possibilities.sort.max_by { |p| total_quantities(p) }
      self[:basket_quantities] = best_possibility
    end
  end

  def set_basket_quantities_manually
    self[:basket_percentages] = basket_percentages_pro_rated

    non_zero_qts = @quantities.compact.reject { |_, p| p.to_i.zero? }
    self[:basket_size_ids] = non_zero_qts.keys
    self[:basket_quantities] =
      case unit
      when "kg"; non_zero_qts.values.map { |q| q.to_f / 1000.0 }
      when "pc"; non_zero_qts.values.map(&:to_i)
      end
    set_baskets_counts
  end

  def possibility(roundings)
    basket_size_ids.map.with_index do |bs, i|
      round(quantity * ratio(bs), roundings[i])
    end
  end

  def ratio(basket_size)
    basket_count = baskets_count(basket_size)
    return 0 if basket_count.zero?

    total = basket_size_ids.sum { |bs| baskets_count(bs) * basket_percentage(bs) }
    basket_percentage(basket_size) / total.to_f
  end

  def total_quantities(quantities)
    quantities.map.with_index { |qt, i| qt * baskets_counts[i] }.sum
  end

  def round(quantity, direction)
    case direction
    when :up; round_unit(quantity, :ceil, 0)
    when :upup; round_unit(quantity, :ceil, 1)
    when :down; round_unit(quantity, :floor, 0)
    when :downdown; round_unit(quantity, :floor, -1)
    end
  end

  def round_unit(quantity, method, diff)
    case unit
    when "kg"; ((quantity * 1000).send(method) + diff) / 1000.0
    when "pc"; quantity.send(method) + diff
    end
  end

  def update_delivery_basket_content_avg_prices!
    delivery.update_basket_content_avg_prices!
  end
end
