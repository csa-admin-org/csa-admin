class BasketContent < ApplicationRecord
  UNITS = %w[kilogramme pièce]

  belongs_to :delivery, required: true
  belongs_to :vegetable, required: true
  has_and_belongs_to_many :distributions

  scope :basket_eq, ->(type) {
    case type
    when 'small' then where('small_basket_quantity > 0')
    when 'big' then where('big_basket_quantity > 0')
    end
  }

  validates :quantity, presence: true
  validates :basket_types, :distributions, presence: true
  validates :unit, inclusion: { in: UNITS }
  validates :vegetable, uniqueness: { scope: :delivery_id }

  attr_accessor :same_basket_quantities
  attr_writer :basket_types

  before_save :set_basket_counts_and_quantities

  def basket_types
    @basket_types ||
      [].tap { |types|
        types << 'small' unless small_baskets_count.zero?
        types << 'big' unless big_baskets_count.zero?
      }
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i[basket_eq]
  end

  def small_basket
    @small_basket ||= Basket.small.where(year: delivery.date.year).first
  end

  def big_basket
    @big_basket ||= Basket.big.where(year: delivery.date.year).first
  end

  def same_basket_quantities
    both_baskets? && @same_basket_quantities == '1'
  end

  def both_baskets?
    (basket_types & %w[small big]) == %w[small big]
  end

  private

  def set_basket_counts_and_quantities
    set_basket_counts
    set_basket_quantities
  end

  def set_basket_counts
    return if Rails.env.test?

    self.small_baskets_count = 0
    self.big_baskets_count = 0
    delivery_distributions = Distribution.with_delivery_memberships(delivery)
    delivery_distributions.select! { |dd| dd.id.in?(distribution_ids) }
    delivery_distributions.each do |distribution|
      memberships = distribution.delivery_memberships.to_a
      if basket_types.include?('small')
        self.small_baskets_count += memberships.count { |m| m.basket.small? }
      end
      if basket_types.include?('big')
        self.big_baskets_count += memberships.count { |m| m.basket.big? }
      end
    end
  end

  def set_basket_quantities
    s_qt = quantity * small_basket_ratio
    b_qt = quantity * big_basket_ratio
    possibilites = [
      possibility(s_qt, :up, b_qt, :up),
      possibility(s_qt, :down, b_qt, :up),
      possibility(s_qt, :up, b_qt, :down),
      possibility(s_qt, :down, b_qt, :down)
    ].reject { |p| p.lost_quantity.negative? }
    best_possibility = possibilites.sort_by!(&:lost_quantity).first
    self.small_basket_quantity = best_possibility.small_quantity
    self.big_basket_quantity = best_possibility.big_quantity
    self.lost_quantity = best_possibility.lost_quantity
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
    small_baskets_count * small_basket.price + big_baskets_count * big_basket.price
  end

  def possibility(small_quantity, small_round_direction, big_quantity, big_round_direction)
    s_qt = round(small_quantity, small_round_direction)
    # Splits small lost to big baskets
    if s_qt.positive? && big_baskets_count.positive? && small_round_direction == :down
      lost_s_qt = small_baskets_count * (small_quantity - s_qt)
      big_quantity += lost_s_qt / big_baskets_count.to_f
    end
    b_qt = round(big_quantity, big_round_direction)
    lost = quantity - s_qt * small_baskets_count - b_qt * big_baskets_count
    # p "#{s_qt} (#{small_round_direction}) // #{b_qt} (#{big_round_direction}) // #{lost}"

    OpenStruct.new(
      small_quantity: s_qt,
      big_quantity: b_qt,
      lost_quantity: lost
    )
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
    end
  end
end
