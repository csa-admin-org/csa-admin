# frozen_string_literal: true

class BiddingRound::CompletionJob < ApplicationJob
  queue_as :default

  def perform(bidding_round, membership)
    if pledge = bidding_round.pledges.find_by(membership: membership)
      membership.update!(basket_size_price: pledge.basket_size_price)
    end

    membership.reload # Ensure updated price
    MailTemplate.deliver_later(:bidding_round_completed,
      bidding_round: bidding_round,
      member: membership.member)
  end
end
