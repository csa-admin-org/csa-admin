# frozen_string_literal: true

class Members::BasketShiftsController < Members::BaseController
  before_action :load_basket
  before_action :ensure_member_can_shift_basket!

  # GET /baskets/:id/shift
  def new
  end

  # CREATE /baskets/:id/shift
  def create
    @basket.update!(basket_params)

    redirect_to members_deliveries_path, notice: t(".flash.notice")
  end

  private

  def load_basket
    @basket = current_member.baskets.find(params[:basket_id])
  end

  def ensure_member_can_shift_basket!
    return if @basket.membership.basket_shift_allowed?
    return if @basket.can_be_member_shifted?

    redirect_to members_deliveries_path, alert: t(".flash.alert")
  end

  def basket_params
    permitted = params.require(:basket).permit(:shift_target_basket_id)
    if permitted[:shift_target_basket_id] != "declined"
      allowed_ids = @basket.member_shiftable_basket_targets.map(&:id).map(&:to_s)
      unless permitted[:shift_target_basket_id].in?(allowed_ids)
        permitted.delete(:shift_target_basket_id)
      end
    end
    permitted
  end
end
