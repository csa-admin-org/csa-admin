# frozen_string_literal: true

class BiddingRound::Pledge < ApplicationRecord
  self.table_name = "bidding_round_pledges"

  belongs_to :bidding_round
  belongs_to :membership
  has_one :member, through: :membership

  validates :membership,
    presence: true,
    uniqueness: { scope: [ :bidding_round_id ] }
  validates :basket_size_price,
    presence: true,
    numericality: { greater_or_equal_to_than: 0 }
  validate :basket_size_price_within_allowed_range
  validate :bidding_round_must_be_open
  validate :membership_must_match_bidding_round_fiscal_year

  def total_membership_price
    basket_size_price * membership.basket_quantity * membership.baskets_count
  end

  def price_difference_from_default
    basket_size_price - membership.basket_size.price
  end

  private

  def basket_size_price_within_allowed_range
    return unless membership
    return unless basket_size_price

    default_price = membership.basket_size.price
    min_percentage = Current.org.bidding_round_basket_size_price_min_percentage
    max_percentage = Current.org.bidding_round_basket_size_price_max_percentage

    min_price = default_price * (min_percentage / 100.0)
    max_price = default_price * ((100 + max_percentage) / 100.0)

    if basket_size_price < min_price
      errors.add(:basket_size_price, :invalid)
    elsif basket_size_price > max_price
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
end
