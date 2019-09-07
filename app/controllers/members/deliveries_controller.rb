class Members::DeliveriesController < Members::BaseController
  # GET /deliveries
  def index
    if @next_basket = current_member.next_basket
      baskets = @next_basket.membership.baskets.includes(:delivery, :basket_size, :depot)
      @future_baskets = baskets.coming.where.not(id: @next_basket.id)
      @past_baskets = baskets.delivered
    end
  end
end
