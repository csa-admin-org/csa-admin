class Members::MembersController < Members::BaseController
  skip_before_action :authenticate_member!, only: %i[new create welcome]
  before_action :redirect_current_member!, only: %i[new create welcome]
  invisible_captcha only: :create

  # GET /new
  def new
    @member = Member.new
    set_basket_complements
  end

  # GET /
  def show
    if current_member.next_basket
      redirect_to members_deliveries_path
    elsif Current.acp.feature?('activity')
      redirect_to members_activity_participations_path
    else
      redirect_to members_billing_path
    end
  end

  # POST /
  def create
    @member = Member.new(member_params)
    @member.language = I18n.locale
    @member.public_create = true

    if SpamDetector.spam?(@member)
      SpamDetector.notify!(@member)
      redirect_to welcome_members_member_path
    elsif @member.save
      redirect_to welcome_members_member_path
    else
      set_basket_complements
      render :new
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
        .select { |bc| bc.deliveries_count.positive? }
        .map(&:id)
    mbcs = @member.members_basket_complements.to_a
    @member.members_basket_complements.clear
    complement_ids.each do |id|
      quantity = mbcs.find { |mbc| mbc.basket_complement_id == id }&.quantity
      @member.members_basket_complements.build(
        quantity: quantity || 0,
        basket_complement_id: id)
    end
  end

  def member_params
    permitted = params
      .require(:member)
      .permit(
        :name, :address, :zip, :city, :country_code,
        :emails, :phones,
        :waiting_basket_size_id, :waiting_basket_price_extra, :waiting_depot_id,
        :billing_year_division,
        :profession, :come_from, :note,
        :terms_of_service,
        waiting_alternative_depot_ids: [],
        members_basket_complements_attributes: [
          :basket_complement_id, :quantity
        ])
    permitted[:members_basket_complements_attributes]&.select! { |i, attrs|
      attrs['quantity'].to_i > 0
    }
    permitted[:waiting_alternative_depot_ids]&.map!(&:presence)&.compact!
    permitted
  end
end
