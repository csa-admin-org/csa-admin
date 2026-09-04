# frozen_string_literal: true

class Members::HomeDeliveryAddressesController < Members::BaseController
  before_action :load_basket, only: :new
  before_action :load_overlay, only: %i[edit update destroy]

  def new
    unless HomeDeliveryAddress.can_member_create_for?(@basket)
      redirect_to members_deliveries_path and return
    end

    @home_delivery_address = current_member.home_delivery_addresses.build(
      delivery_ids: [ @basket.delivery_id ])
    @home_delivery_address.member_managed = true
  end

  def create
    @home_delivery_address = current_member.home_delivery_addresses.build(overlay_params)
    @home_delivery_address.member_managed = true

    unless member_can_create_overlay?
      redirect_to members_deliveries_path and return
    end

    if @home_delivery_address.save
      redirect_to members_deliveries_path, notice: t(".flash.notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    unless @home_delivery_address.can_member_update?
      redirect_to members_deliveries_path and return
    end
  end

  def update
    unless @home_delivery_address.can_member_update?
      redirect_to members_deliveries_path and return
    end

    @home_delivery_address.member_managed = true
    if @home_delivery_address.update(overlay_params)
      redirect_to members_deliveries_path, notice: t(".flash.notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @home_delivery_address.can_member_destroy?
      redirect_to members_deliveries_path and return
    end

    @home_delivery_address.destroy
    redirect_to members_deliveries_path, notice: t(".flash.destroyed")
  end

  private

  def load_basket
    @basket = current_member.baskets.find(params[:basket_id])
  end

  def load_overlay
    @home_delivery_address = current_member.home_delivery_addresses.find(params[:id])
  end

  def overlay_params
    params.require(:home_delivery_address).permit(
      :name, :street, :zip, :city, :note, delivery_ids: [])
  end

  def member_can_create_overlay?
    delivery_ids = @home_delivery_address.delivery_ids.uniq
    return true if delivery_ids.blank?

    baskets = current_member.baskets.where(delivery_id: delivery_ids).includes(:depot, :delivery)
    return false unless baskets.size == delivery_ids.size

    baskets.all? { |basket| HomeDeliveryAddress.can_member_create_for?(basket) }
  end
end
