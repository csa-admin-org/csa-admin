class BasketContent < ApplicationRecord
  UNITS = %w[kilogramme pièce]
  SIZES = %w[small big]

  belongs_to :delivery
  belongs_to :vegetable
  has_and_belongs_to_many :depots

  scope :basket_size_eq, ->(type) {
    case type
    when 'small' then where('small_basket_quantity > 0')
    when 'big' then where('big_basket_quantity > 0')
    end
  }

  before_validation :set_basket_counts, :set_basket_quantities

  validates :delivery, presence: true
  validates :quantity, presence: true
  validates :depots, presence: true
  validates :unit, inclusion: { in: UNITS }
  validates :vegetable_id, uniqueness: { scope: :delivery_id }
  validate :basket_sizes_presence
  validate :enough_quantity

  def self.ransackable_scopes(_auth_object = nil)
    %i[basket_size_eq]
  end

  def small_basket
    @small_basket ||= BasketSize.reorder(:price).first
  end

  def big_basket
    @big_basket ||= BasketSize.reorder(:price).last
  end

  def basket_sizes
    self[:basket_sizes] & SIZES
  end

  def same_basket_quantities
    both_baskets? && self[:same_basket_quantities]
  end

  def both_baskets?
    basket_sizes == SIZES
  end

  private

  def basket_sizes_presence
    if basket_sizes.empty?
      errors.add(:basket_sizes, :blank)
    end
  end

  def enough_quantity
    if small_baskets_count > 0 && small_basket_quantity == 0 ||
      big_baskets_count > 0 && big_basket_quantity == 0
      errors.add(:quantity, :insufficient)
    end
  end

  def set_basket_counts
    return unless delivery

    self[:small_baskets_count] = 0
    self[:big_baskets_count] = 0
    baskets = delivery.baskets.not_absent.where(depot_id: depot_ids)
    if basket_sizes.include?('small')
      self[:small_baskets_count] = baskets.where(basket_size_id: small_basket.id).sum(:quantity)
    end
    if basket_sizes.include?('big')
      self[:big_baskets_count] = baskets.where(basket_size_id: big_basket.id).sum(:quantity)
    end
  end

  def set_basket_quantities
    return unless quantity

    s_qt = quantity * small_basket_ratio
    b_qt = quantity * big_basket_ratio
    possibilites = [
      possibility(s_qt, :up, b_qt, :up),
      possibility(s_qt, :down, b_qt, :up),
      possibility(s_qt, :up, b_qt, :down),
      possibility(s_qt, :down, b_qt, :down),
      possibility(s_qt, :double_down, b_qt, :up),
      possibility(s_qt, :double_down, b_qt, :down),
      possibility(s_qt, :up, b_qt, :double_down),
      possibility(s_qt, :down, b_qt, :double_down)
    ].reject { |p| p.surplus_quantity.negative? }
    best_possibility = possibilites.sort_by!(&:surplus_quantity).first
    self.small_basket_quantity = best_possibility.small_quantity
    self.big_basket_quantity = best_possibility.big_quantity
    self.surplus_quantity = best_possibility.surplus_quantity
  end

  def small_basket_ratio
    @small_basket_ratio ||=
      if small_baskets_count.zero?
        0
      elsif big_baskets_count.zero?
        1 / small_baskets_count.to_f
      elsif same_basket_quantities
        1 / (small_baskets_count + big_baskets_count).to_f
      else
        small_basket.price / total_baskets_price.to_f
      end
  end

  def big_basket_ratio
    @big_basket_ratio ||=
      if big_baskets_count.zero?
        0
      elsif small_baskets_count.zero?
        1 / big_baskets_count.to_f
      elsif same_basket_quantities
        1 / (small_baskets_count + big_baskets_count).to_f
      else
        big_basket.price / total_baskets_price.to_f
      end
  end

  def total_baskets_price
    @total_baskets_price ||=
      small_baskets_count * small_basket.price +
        big_baskets_count * big_basket.price
  end

  def possibility(small_quantity, small_round_direction, big_quantity, big_round_direction)
    s_qt = round(small_quantity, small_round_direction)
    # Splits small surplus to big baskets
    if s_qt.positive? && big_baskets_count.positive? && small_round_direction == :down
      surplus_s_qt = small_baskets_count * (small_quantity - s_qt)
      big_quantity += surplus_s_qt / big_baskets_count.to_f
    end
    b_qt = round(big_quantity, big_round_direction)
    surplus = quantity - s_qt * small_baskets_count - b_qt * big_baskets_count

    OpenStruct.new(
      small_quantity: s_qt,
      big_quantity: b_qt,
      surplus_quantity: surplus)
  end

  def round(quantity, direction)
    case direction
    when :up
      case unit
      when 'kilogramme' then (quantity * 100).ceil / 100.0
      when 'pièce' then quantity.ceil
      end
    when :down
      case unit
      when 'kilogramme' then (quantity * 100).floor / 100.0
      when 'pièce' then quantity.floor
      end
    when :double_down
      case unit
      when 'kilogramme' then ((quantity * 100).floor - 1) / 100.0
      when 'pièce' then quantity.floor - 1
      end
    end
  end
end
