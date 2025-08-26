# frozen_string_literal: true

class Liquid::BiddingRoundDrop < Liquid::Drop
  def initialize(bidding_round)
    @bidding_round = bidding_round
  end

  def title
    @bidding_round.title
  end

  def number
    @bidding_round.number
  end

  def fiscal_year
    @bidding_round.fiscal_year.to_s
  end

  def information_text
    @bidding_round.information_text.to_s
  end
end
