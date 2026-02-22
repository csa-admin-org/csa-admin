# frozen_string_literal: true

class Members::BiddingRound::PledgesController < Members::BaseController
  include BiddingRoundsHelper

  before_action :ensure_bidding_round
  before_action :load_bidding_round
  before_action :find_or_initialize_pledge

  def new
    @pledge.basket_size_price = params[:price] if params[:price].present?
  end

  def create
    @pledge.assign_attributes(pledge_params)

    if @pledge.save
      redirect_to members_memberships_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def ensure_bidding_round
    return if display_bidding_round? && open_bidding_round.eligible?(current_member)

    redirect_to members_member_path
  end

  def load_bidding_round
    @bidding_round ||= open_bidding_round
  end

  def find_or_initialize_pledge
    membership = @bidding_round.eligible_memberships.find_by(member: current_member)
    @pledge ||= @bidding_round.pledges.find_or_initialize_by(membership: membership)
  end

  def pledge_params
    params.require(:bidding_round_pledge).permit(:basket_size_price)
  end
end
