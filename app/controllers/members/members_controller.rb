class Members::MembersController < Members::BaseController
  skip_before_action :authenticate_member!, only: %i[new create welcome]

  # GET /new
  def new
    @member = Member.new
  end

  # GET /
  def show; end

  # POST /
  def create
    @member = Member.new(member_params)
    @member.language = I18n.locale
    @member.public_create = true

    if @member.save
      redirect_to welcome_members_member_path
    else
      render :new
    end
  end

  # GET /welcome
  def welcome; end

  private

  def member_params
    params
      .require(:member)
      .permit(
        :name, :address, :zip, :city,
        :emails, :phones,
        :waiting_basket_size_id, :waiting_distribution_id,
        :billing_year_division,
        :profession, :come_from, :note,
        :terms_of_service,
        waiting_basket_complement_ids: [])
  end
end
