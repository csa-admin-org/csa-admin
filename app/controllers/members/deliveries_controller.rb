class Members::DeliveriesController < Members::BaseController
  # GET /deliveries
  def index
    if @next_basket = current_member.next_basket
      membership_ids = [ @next_basket.membership_id ]
      if current_member.future_membership
        membership_ids << current_member.future_membership.id
      end
      @future_baskets =
        Basket
          .where(membership_id: membership_ids)
          .filled
          .coming
          .includes(:delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement)
      @past_baskets =
        @next_basket
          .membership
          .baskets
          .filled
          .past
          .includes(:delivery, :basket_size, :depot, baskets_basket_complements: :basket_complement)
    else
      redirect_to members_login_path
    end
  end
end
