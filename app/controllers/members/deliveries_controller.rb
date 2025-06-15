# frozen_string_literal: true

class Members::DeliveriesController < Members::BaseController
  before_action :ensure_baskets

  # GET /deliveries
  def index
    @next_basket = current_member.next_basket
    @future_baskets =
      Basket
        .where(membership_id: current_member.memberships)
        .coming
        .includes(:delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement)
    @past_baskets =
      current_member
        .closest_membership
        .baskets
        .past
        .joins(:delivery)
        .includes(:basket_size, :depot, baskets_basket_complements: :basket_complement)
        .reorder(deliveries: { date: :desc })
  end

  private

  def ensure_baskets
    return if current_member.baskets.any?

    redirect_to members_login_path
  end
end
