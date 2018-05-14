class Members::MembersController < Members::ApplicationController
  skip_before_action :authenticate_member!, only: %i[new create welcome]

  # GET /new
  def new
    @member = Member.new
  end

  # GET /:token
  def show; end

  # POST
  def create
    @member = Member.new(member_params)
    @member.public_create = true

    if @member.save
      redirect_to welcome_members_members_path
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
        :emails, :phones, :language,
        :waiting_basket_size_id, :waiting_distribution_id,
        :billing_year_division,
        :profession, :come_from, :note,
        :terms_of_service,
        waiting_basket_complement_ids: [])
  end
end
