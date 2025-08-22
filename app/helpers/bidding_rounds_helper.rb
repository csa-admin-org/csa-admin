# frozen_string_literal: true

module BiddingRoundsHelper
  def display_bidding_round?
    Current.org.feature?("bidding_round") && open_bidding_round
  end

  def missing_bidding_round_pledge?
    return unless display_bidding_round?

    open_bidding_round.eligible?(current_member) && !open_bidding_round.pledged?(current_member)
  end

  def open_bidding_round
    @open_bidding_round ||= BiddingRound.current_open
  end

  def open_bidding_round_pledge(membership)
    return unless display_bidding_round?

    open_bidding_round.pledges.find_by(membership: membership)
  end

  def open_bidding_round_for?(membership)
    return unless display_bidding_round?

    open_bidding_round.eligible_memberships.exists?(id: membership)
  end
end
