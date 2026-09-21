# frozen_string_literal: true

class Members::MembersController < Members::BaseController
  include ActivitiesHelper
  include ShopHelper
  include CapVerifiable

  skip_before_action :authenticate_member!, only: %i[new create]
  skip_before_action :verify_cap, if: :current_member
  prepend_before_action :redirect_current_member!, only: %i[new create]

  def new
    @member = current_member || Member.new
    @member.public_create = true
    if params[:member]
      @member.assign_attributes(member_params)
    else
      @member.assign_waiting_from_last_membership if current_member
      @member.waiting_activity_participations_demanded_annually ||=
        Current.org.activity_participations_form_min.to_i
      if Current.org.feature?("shares")
        @member.desired_shares_number ||= Current.org.shares_number
      end
      if params[:basket_size_id]
        @member.waiting_basket_size_id = params[:basket_size_id]
      end
      if params[:different_billing_info] == "true"
        @member.different_billing_info = true
      end
    end
    set_basket_complements
  end

  def show
    if current_member.next_basket
      redirect_to members_deliveries_path
    elsif show_shop_menu?
      redirect_to shop_path
    elsif display_activity?
      redirect_to members_activity_participations_path
    else
      redirect_to members_billing_path
    end
  end

  def create
    if current_member
      member = current_member
    else
      member = Member.new(member_params)
      member.language = I18n.locale
    end
    member.public_create = true

    registration = MemberRegistration.new(member, member_params)
    if registration.save
      if current_member
        redirect_to members_memberships_path, notice: t(".flash.notice")
      else
        redirect_to members_public_page_path("welcome")
      end
    else
      @member = registration.member
      set_basket_complements
      render :new, status: :unprocessable_entity
    end
  end

  private

  def cap_after_failure
    @member = Member.new(member_params)
    @member.public_create = true
    set_basket_complements
    flash.now[:alert] = t("cap.failed_retry")
    render :new, status: :unprocessable_entity
  end

  def redirect_current_member!
    redirect_to members_member_path if current_member && !current_member.can_re_register?
  end

  def set_basket_complements
    complements =
      BasketComplement
        .visible
        .preload(:future_deliveries, :current_deliveries)
        .member_ordered
        .select { |complement| complement.deliveries_count.positive? }
    members_basket_complements = @member.members_basket_complements
    quantities = members_basket_complements.to_a.index_by(&:basket_complement_id)
    members_basket_complements.target.replace([])
    complements.each do |complement|
      quantity = params.dig(:basket_complements, complement.id.to_s)
      quantity ||= quantities[complement.id]&.quantity || 0
      members_basket_complements.build(quantity: quantity, basket_complement: complement)
    end
  end

  def member_params
    permitted = params
      .require(:member)
      .permit(
        :name, :street, :zip, :city, :country_code,
        :emails, :phones,
        :waiting_basket_size_id, :waiting_basket_price_extra,
        :waiting_activity_participations_demanded_annually,
        :waiting_depot_id, :waiting_delivery_cycle_id,
        :waiting_billing_year_division,
        :annual_fee, :desired_shares_number,
        :shop_depot_id,
        :different_billing_info,
        :billing_name, :billing_street, :billing_zip, :billing_city,
        :profession, :come_from, :note,
        :terms_of_service,
        waiting_alternative_depot_ids: [],
        members_basket_complements_attributes: [
          :basket_complement_id, :quantity
        ])
    permitted[:members_basket_complements_attributes]&.select! { |i, attrs|
      attrs["quantity"].to_i > 0
    }
    permitted[:waiting_alternative_depot_ids]&.map!(&:presence)&.compact!
    permitted.delete(:annual_fee) unless Current.org.feature?("annual_fee")
    permitted.delete(:desired_shares_number) unless Current.org.feature?("shares")
    permitted
  end
  helper_method :member_params

  def shop_path
    if current_shop_delivery&.shop_open?
      members_shop_path
    elsif next_shop_delivery
      members_shop_next_path
    elsif shop_special_deliveries.any?
      members_shop_special_delivery_path(shop_special_deliveries.first.date)
    else
      members_shop_path
    end
  end
end
