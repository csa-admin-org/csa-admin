# frozen_string_literal: true

class Members::BasketShiftsController < Members::BaseController
  before_action :load_basket
  before_action :ensure_member_can_shift_basket!

  def new
  end

  def create
    Basket.transaction do
      target_id = resolve_shift_target_id
      if target_id.present? && target_id != "declined" && !@basket.absence_id?
        @basket.ensure_definite_absence!
      end
      @basket.update!(shift_target_basket_id: target_id) if target_id
    end

    redirect_to members_deliveries_path, notice: t(".flash.notice")
  end

  private

  def load_basket
    @basket = current_member.baskets
      .includes(:delivery, :baskets_basket_complements)
      .find(params[:basket_id])
  end

  def ensure_member_can_shift_basket!
    return if @basket.can_be_member_shifted?

    redirect_to members_deliveries_path, alert: t(".flash.alert")
  end

  def resolve_shift_target_id
    raw = params.require(:basket).permit(:shift_target_basket_id)[:shift_target_basket_id]
    return if raw.blank?
    return "declined" if raw == "declined"

    if raw.start_with?("delivery:")
      delivery_id = raw.delete_prefix("delivery:")
      delivery = @basket.member_off_cycle_shift_deliveries.find { |d| d.id.to_s == delivery_id }
      return unless delivery

      @basket.membership.create_shift_receptacle!(delivery).id
    else
      raw if @basket.member_shiftable_basket_targets.map(&:id).map(&:to_s).include?(raw)
    end
  end
end
