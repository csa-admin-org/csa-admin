# frozen_string_literal: true

class Members::MembershipRenewalsController < Members::BaseController
  before_action :load_membership
  before_action :ensure_renewal_opened!, only: :new
  before_action :redirect_renewal_decision_params!, only: :new

  # GET /membership/renewal/new
  # GET /membership/:decision
  def new
    @membership = @membership.dup
    @membership.renewal_decision = params[:decision]
    set_basket_complements
  end

  # POST /membership/renewal
  def create
    case params.require(:membership).require(:renewal_decision)
    when "cancel"
      @membership.cancel!(renewal_params)
      flash[:notice] = t(".flash.canceled")
    when "renew"
      @membership.renew!(renewal_params)
      flash[:notice] = t(".flash.renewed")
    end

    redirect_to members_memberships_path
  rescue => e
    Error.report(e,
      member_id: current_member.id,
      membership_id: @membership&.id)
    redirect_back fallback_location: members_memberships_path, alert: t(".flash.error")
  end

  private

  def load_membership
    @membership = current_member.last_membership
    raise ActiveRecord::RecordNotFound unless @membership&.renewal_opened?
  end

  def set_basket_complements
    complement_ids =
      BasketComplement
        .visible
        .member_ordered
        .select { |bc| bc.deliveries_count.positive? }
        .map(&:id)
    complement_ids.each do |id|
      quantity =
        current_member
          .last_membership
          .memberships_basket_complements
          .find { |mbc| mbc.basket_complement_id == id }
          &.quantity
      @membership.memberships_basket_complements.build(
        quantity: quantity || 0,
        basket_complement_id: id)
    end
  end

  def ensure_renewal_opened!
    return if @membership.renewal_opened?

    redirect_to members_member_path
  end

  def redirect_renewal_decision_params!
    # Avoid redirect for pricing frame update
    return if params.dig(:membership, :renewal_note)

    if decision = params.dig(:membership, :renewal_decision)
      redirect_to url_for(decision: decision)
    end
  end

  def renewal_params
    permitted = params
      .require(:membership)
      .permit(*%i[
        renewal_annual_fee
        renewal_note
        basket_size_id
        basket_price_extra
        activity_participations_demanded_annually
        depot_id
        delivery_cycle_id
        billing_year_division
      ], memberships_basket_complements_attributes: [
        :basket_complement_id, :quantity
      ])
      permitted[:memberships_basket_complements_attributes]&.select! { |i, attrs|
        attrs["quantity"].to_i > 0
      }
      permitted
  end
  helper_method :renewal_params
end
