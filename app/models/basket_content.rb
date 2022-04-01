class BasketContent < ApplicationRecord
  UNITS = %w[kg pc]

  belongs_to :delivery
  belongs_to :vegetable
  has_and_belongs_to_many :depots

  scope :basket_size_eq, ->(id) { where('basket_size_ids @> ?', "{#{id}}") }
  scope :for_depot, ->(depot) {
    joins(:depots).where('basket_contents_depots.depot_id = ?', depot)
  }

  before_validation :set_baskets_counts, :set_basket_quantities

  validates :delivery, presence: true
  validates :quantity, presence: true
  validates :depots, presence: true
  validates :unit, inclusion: { in: UNITS }
  validate :basket_size_ids_presence
  validate :enough_quantity

  def self.ransackable_scopes(_auth_object = nil)
    %i[basket_size_eq]
  end

  def basket_size_ids=(ids)
    super ids.map(&:presence).compact.map(&:to_i).sort
  end

  def basket_sizes
    @basket_sizes ||= BasketSize.reorder(:id).find(basket_size_ids)
  end

  def same_basket_quantities
    basket_size_ids.many? && self[:same_basket_quantities]
  end

  def basket_quantity(basket_size)
    if i = basket_size_index(basket_size)
      basket_quantities[i]
    end
  end

  def baskets_count(basket_size)
    if i = basket_size_index(basket_size)
      baskets_counts[i]
    end
  end

  private

  def basket_size_index(basket_size)
    id = basket_size.respond_to?(:id) ? basket_size.id : basket_size
    basket_size_ids.index(id)
  end

  def basket_size_ids_presence
    if basket_size_ids.empty?
      errors.add(:basket_size_ids, :blank)
    end
  end

  def enough_quantity
    if basket_quantities.empty?
      errors.add(:quantity, :insufficient)
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

  def set_basket_quantities
    return unless quantity

    roundings = %i[up upup down downdown]
    permutations = roundings.repeated_permutation(basket_size_ids.size)
    possibilities = permutations.map { |r| possibility(r) }
    possibilities.reject! { |p| p.any? { |q| q <= 0 } || total_quantities(p) > quantity }
    if best_possibility = possibilities.sort.max_by { |p| total_quantities(p) }
      self[:basket_quantities] = best_possibility
      self[:surplus_quantity] = quantity - total_quantities(best_possibility)
    end
  end

  def possibility(roundings)
    basket_sizes.map.with_index do |basket_size, i|
      round(quantity * ratio(basket_size), roundings[i])
    end
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
    when 'kg'; ((quantity * 100).send(method) + diff) / 100.0
    when 'pc'; quantity.send(method) + diff
    end
  end

  def ratio(basket_size)
    baskets_count = baskets_count(basket_size)
    if baskets_count.zero?
      0
    elsif basket_size_ids.one?
      1 / baskets_count.to_f
    elsif same_basket_quantities
      1 / baskets_counts.sum.to_f
    else
      basket_size.price / total_prices.to_f
    end
  end

  def total_prices
    @total_prices ||= basket_sizes.sum { |bs| baskets_count(bs) * bs.price }
  end
end
