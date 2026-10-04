# frozen_string_literal: true

class Members::MembershipRenewalsController < Members::BaseController
  before_action :load_membership
  before_action :ensure_member_can_decide_renewal!
  before_action :redirect_renewal_decision_params!, only: :new

  def new
    reduction = @membership.price_reduction
    @membership = @membership.dup
    @membership.renewal_decision = params[:decision]
    if reduction&.renew? && reduction.visible? && !reduction.discarded?
      @membership.selected_price_reduction_id = reduction.id
    end
    set_basket_complements
  end

  def create
    case params.require(:membership).require(:renewal_decision)
    when "cancel"
      @membership.cancel!(renewal_params)
      flash[:notice] = t(".flash.canceled")
    when "renew"
      save_renewal_cards!
      membership = @membership.renew!(renewal_params)
      flash[:notice] = t(".flash.renewed")
      flash[:alert] = t(".flash.price_reduction_skipped") if membership.price_reduction_skipped
    end

    redirect_to members_memberships_path
  rescue => e
    Rails.error.report(e, context: {
      member_id: current_member.id,
      membership_id: @membership&.id
    })
    redirect_back fallback_location: members_memberships_path, alert: t(".flash.error")
  end

  private

  def load_membership
    @membership = current_member.last_membership
    raise ActiveRecord::RecordNotFound unless @membership&.renewal_opened?
  end

  def ensure_member_can_decide_renewal!
    return if @membership.member_can_decide_renewal?

    redirect_to member_renewal_fallback_path
  end

  def member_renewal_fallback_path
    if current_member.can_re_register?
      new_members_member_path
    else
      members_memberships_path
    end
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

  def redirect_renewal_decision_params!
    return if params.dig(:membership, :renewal_note) # pricing frame update

    if decision = params.dig(:membership, :renewal_decision)
      redirect_to url_for(decision: decision)
    end
  end

  def save_renewal_cards!
    return unless Current.org.feature?("price_reductions")

    cards = params.fetch(:membership, {}).permit(
      :selected_price_reduction_id,
      member_cards_attributes: [ :id, :price_reduction_card_id, :name, :number, :expires_on ])
    PriceReduction.scope_public_params(cards, :selected_price_reduction_id)
    return if cards[:member_cards_attributes].blank?

    current_member.update!(cards.except(:selected_price_reduction_id))
  end

  def renewal_params
    permitted = params
      .require(:membership)
      .permit(*renewal_permitted_keys,
        memberships_basket_complements_attributes: [
          :basket_complement_id, :quantity
        ],
        member_cards_attributes: [
          :id, :price_reduction_card_id, :name, :number, :expires_on
        ])
    permitted[:memberships_basket_complements_attributes]&.select! { |i, attrs|
      attrs["quantity"].to_i > 0
    }
    if Current.org.feature?("price_reductions")
      PriceReduction.scope_public_params(permitted, :selected_price_reduction_id)
    else
      permitted.delete(:member_cards_attributes)
    end
    permitted
  end

  def renewal_permitted_keys
    keys = %i[
      renewal_annual_fee
      renewal_note
      basket_size_id
      activity_participations_demanded_annually
      depot_id
      delivery_cycle_id
      billing_year_division
    ]
    keys << :basket_price_extra if Current.org.feature?("basket_price_extra")
    keys << :selected_price_reduction_id if Current.org.feature?("price_reductions")
    keys
  end
  helper_method :renewal_params
end
