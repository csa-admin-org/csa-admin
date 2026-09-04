# frozen_string_literal: true

class Members::DeliveriesController < Members::BaseController
  before_action :ensure_baskets

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
        .includes(:membership, :absence, :basket_size, :depot, delivery: :basket_complements, baskets_basket_complements: :basket_complement)
    @past_baskets =
      current_member
        .closest_membership
        .baskets
        .past
        .joins(:delivery)
        .includes(:basket_size, :absence, :depot, delivery: :basket_complements, baskets_basket_complements: :basket_complement)
        .reorder(deliveries: { date: :desc })
    @home_delivery_overlays_by_delivery_id =
      HomeDeliveryAddress.by_delivery_id_for_member(current_member)
    @home_delivery_cta_basket = home_delivery_cta_basket
  end

  private

  def ensure_baskets
    return if current_member.baskets.any?

    redirect_to members_login_path
  end

  def home_delivery_cta_basket
    overlays = @home_delivery_overlays_by_delivery_id
    [ @next_basket, *@future_baskets ].compact.find { |basket|
      next if basket.delivery.date.today?

      overlays[basket.delivery_id].blank? && HomeDeliveryAddress.can_member_create_for?(basket)
    }
  end
end
