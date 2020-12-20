class Members::DeliveriesController < Members::BaseController
  # GET /deliveries
  def index
    if @next_basket = current_member.next_basket
      membership_ids = [@next_basket.membership_id]
      if current_member.future_membership
        membership_ids << current_member.future_membership.id
      end
      @future_baskets =
        Basket
          .where(membership_id: membership_ids)
          .where.not(id: @next_basket.id)
          .coming
          .includes(:delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement)
      @past_baskets =
        @next_basket
          .membership.baskets
          .delivered
          .includes(:delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement)
    end
  end
end
