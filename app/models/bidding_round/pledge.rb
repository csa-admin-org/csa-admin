# frozen_string_literal: true

class BiddingRound::Pledge < ApplicationRecord
  self.table_name = "bidding_round_pledges"

  belongs_to :bidding_round
  belongs_to :membership
  has_one :member, through: :membership

  after_initialize do
    self.basket_size_price ||= default_price
  end

  validates :membership,
    presence: true,
    uniqueness: { scope: [ :bidding_round_id ] }
  validates :basket_size_price,
    presence: true,
    numericality: { greater_or_equal_to_than: 0 }
  validate :basket_size_price_within_allowed_range
  validate :bidding_round_must_be_open
  validate :membership_must_match_bidding_round_fiscal_year

  def total_membership_baskets_price
    basket_size_price * membership.basket_quantity * membership.baskets_count
  end

  def total_membership_price
    membership.price - membership.basket_sizes_price + total_membership_baskets_price
  end

  def total_membership_price_difference
    total_membership_price - membership.price
  end

  def price_difference_from_default
    basket_size_price - membership.basket_size.price
  end

  def min_allowed_price
    return 0 unless membership&.basket_size

    default_price = membership.basket_size.price
    min_percentage = Current.org.bidding_round_basket_size_price_min_percentage
    default_price * (min_percentage / 100.0)
  end

  def max_allowed_price
    return 0 unless membership&.basket_size

    default_price = membership.basket_size.price
    max_percentage = Current.org.bidding_round_basket_size_price_max_percentage
    default_price * ((100 + max_percentage) / 100.0)
  end

  def default_price
    previous_round = BiddingRound.previous(bidding_round)
    previous_pledge = previous_round&.pledges&.find_by(membership: membership)

    previous_pledge&.basket_size_price || catalog_basket_size_price || 0
  end

  def default_price_percentage_difference
    baseline = default_price
    return unless baseline&.positive? && basket_size_price

    difference = ((basket_size_price - baseline) / baseline * 100).round
    difference unless difference.zero?
  end

  def default_price_tick_ratio
    scale_ratio(default_price)
  end

  def basket_size_price_tick_ratios
    recommended = default_price&.round(2)
    price_step_ticks.filter_map { |price|
      next if recommended && (price - recommended).abs < 0.01

      scale_ratio(price)
    }
  end

  def basket_size_price_snap_prices
    prices = price_step_ticks
    recommended = default_price
    prices << recommended if recommended && scale_ratio(recommended)
    prices.map { |price| price.to_f.round(2) }.uniq
  end

  private

  def basket_size_price_within_allowed_range
    return unless membership
    return unless basket_size_price

    if basket_size_price < min_allowed_price
      errors.add(:basket_size_price, :invalid)
    elsif basket_size_price > max_allowed_price
      errors.add(:basket_size_price, :invalid)
    end
  end

  def bidding_round_must_be_open
    return unless bidding_round

    unless bidding_round.open?
      errors.add(:bidding_round, :invalid)
    end
  end

  def membership_must_match_bidding_round_fiscal_year
    return unless bidding_round
    return unless membership

    unless membership.fiscal_year == bidding_round.fiscal_year
      errors.add(:membership, :invalid)
    end
  end

  def catalog_basket_size_price
    membership&.basket_size&.price
  end

  def price_step_ticks
    catalog = catalog_basket_size_price
    return [] unless catalog&.positive?

    step = catalog / 10
    min = min_allowed_price
    max = max_allowed_price
    return [] unless max > min

    first = (min / step).ceil
    last = (max / step).floor
    return [] if first > last

    (first..last).map { |index| (step * index).round(2) }
  end

  def scale_ratio(price)
    span = max_allowed_price - min_allowed_price
    return unless span.positive? && price

    ratio = (price.to_d - min_allowed_price.to_d) / span.to_d
    return unless (0..1).cover?(ratio)

    ratio.round(6).to_f
  end
end
