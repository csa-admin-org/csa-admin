# frozen_string_literal: true

module Organization::BiddingRoundFeature
  extend ActiveSupport::Concern

  included do
    validates :bidding_round_basket_size_price_min_percentage,
      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
      presence: true
    validates :bidding_round_basket_size_price_max_percentage,
      numericality: { greater_than_or_equal_to: 1 },
      presence: true
    validates :open_bidding_round_reminder_sent_after_in_days,
      numericality: { greater_than_or_equal_to: 1, allow_nil: true }
  end
end
