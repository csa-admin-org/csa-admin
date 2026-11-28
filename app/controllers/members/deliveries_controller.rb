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
        .includes(:membership, :absence, :basket_size, :depot, :shift_as_source, delivery: :basket_complements, baskets_basket_complements: :basket_complement)
    @this_week_baskets =
      member_baskets.between(Date.current.beginning_of_week...Date.current).to_a
    @past_baskets =
      member_baskets
        .between((Date.current - 1.year)...Date.current)
        .where.not(id: @this_week_baskets)
        .reorder(deliveries: { date: :desc })
        .to_a
    @basket_contents_by_basket_id =
      Basket.contents_by_id(@this_week_baskets + @past_baskets)
    @home_delivery_overlays_by_delivery_id =
      HomeDeliveryAddress.by_delivery_id_for_member(current_member)
    @home_delivery_cta_basket = home_delivery_cta_basket
  end

  private

  def ensure_baskets
    return if current_member.baskets.any?

    redirect_to members_login_path
  end

  def member_baskets
    Basket
      .where(membership_id: current_member.memberships)
      .includes(:basket_size, :absence, :depot, :shift_as_source, delivery: :basket_complements, baskets_basket_complements: :basket_complement)
  end

  def home_delivery_cta_basket
    overlays = @home_delivery_overlays_by_delivery_id
    [ @next_basket, *@future_baskets ].compact.find { |basket|
      next if basket.delivery.date.today?

      overlays[basket.delivery_id].blank? && HomeDeliveryAddress.can_member_create_for?(basket)
    }
  end
end
