# frozen_string_literal: true

class Members::MembersController < Members::BaseController
  include ActivitiesHelper
  include ShopHelper

  skip_before_action :authenticate_member!, only: %i[new create welcome]
  before_action :redirect_current_member!, only: %i[new create welcome]

  # GET /new
  def new
    @member = Member.new(public_create: true)
    @member.desired_shares_number = Current.org.shares_number
    @member.waiting_activity_participations_demanded_annually = Current.org.activity_participations_form_min.to_i
    if params[:basket_size_id]
      @member.waiting_basket_size_id = params[:basket_size_id]
    end
    if params[:different_billing_info] == "true"
      @member.different_billing_info = true
    end
    set_basket_complements

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /
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

  # POST /
  def create
    member = Member.new(member_params)
    member.language = I18n.locale
    member.public_create = true

    if SpamDetector.spam?(member)
      SpamDetector.notify!(member)
      redirect_to welcome_members_member_path
    else
      registration = MemberRegistration.new(member, member_params)
      if registration.save
        redirect_to welcome_members_member_path
      else
        @member = registration.member
        set_basket_complements
        render :new, status: :unprocessable_entity
      end
    end
  end

  # GET /welcome
  def welcome; end

  private

  def redirect_current_member!
    redirect_to members_member_path if current_member
  end

  def set_basket_complements
    complement_ids =
      BasketComplement
        .visible
        .member_ordered
        .select { |bc| bc.deliveries_count.positive? }
        .map(&:id)
    mbcs = @member.members_basket_complements.to_a
    @member.members_basket_complements.clear
    complement_ids.each do |id|
      quantity_params = params.dig(:basket_complements, id.to_s)
      quantity = mbcs.find { |mbc| mbc.basket_complement_id == id }&.quantity
      @member.members_basket_complements.build(
        quantity: quantity_params || quantity || 0,
        basket_complement_id: id)
    end
  end

  def member_params
    permitted = params
      .require(:member)
      .permit(
        :name, :address, :zip, :city, :country_code,
        :emails, :phones,
        :waiting_basket_size_id, :waiting_basket_price_extra,
        :waiting_activity_participations_demanded_annually,
        :waiting_depot_id, :waiting_delivery_cycle_id,
        :waiting_billing_year_division,
        :annual_fee, :desired_shares_number,
        :shop_depot_id,
        :different_billing_info,
        :billing_name, :billing_address, :billing_zip, :billing_city,
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
