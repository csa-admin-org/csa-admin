# frozen_string_literal: true

class Members::DeliveriesController < Members::BaseController
  before_action :ensure_baskets

  # GET /deliveries
  def index
    @next_basket = current_member.next_basket
    if @next_basket && Current.org.basket_content_visible_for_delivery?(@next_basket.delivery)
      @basket_contents = @next_basket.contents
    end
    @future_baskets =
      Basket
        .where(membership_id: current_member.memberships)
        .where.not(id: @next_basket)
        .coming
        .includes(:delivery, :absence, :basket_size, :depot, baskets_basket_complements: :basket_complement)
    @past_baskets =
      current_member
        .closest_membership
        .baskets
        .past
        .joins(:delivery)
        .includes(:basket_size, :absence, :depot, baskets_basket_complements: :basket_complement)
        .reorder(deliveries: { date: :desc })
  end

  private

  def ensure_baskets
    return if current_member.baskets.any?

    redirect_to members_login_path
  end
end
