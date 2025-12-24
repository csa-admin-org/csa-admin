# frozen_string_literal: true

class Members::ForcedDeliveriesController < Members::BaseController
  before_action :load_basket

  # POST /baskets/:basket_id/forced_delivery
  def create
    if @basket.can_member_force?
      ForcedDelivery.create!(basket: @basket)
      redirect_to members_deliveries_path, notice: t(".flash.notice")
    else
      redirect_to members_deliveries_path, alert: t(".flash.alert")
    end
  end

  private

  def load_basket
    @basket = current_member.baskets.find(params[:basket_id])
  end
end
