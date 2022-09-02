class Members::ContactSharingsController < Members::BaseController
  before_action :ensure_contact_sharing_feature
  before_action :ensure_member_next_basket_presence

  # GET /contact_sharing
  def show
    next_basket = current_member.next_basket
    @depot = next_basket.depot
    @members =
      Member
        .sharing_contact
        .where.not(id: current_member.id)
        .joins(:baskets)
        .where(baskets: {
          depot_id: next_basket.depot_id,
          delivery_id: next_basket.delivery_id,
        })
        .order(:name)
  end

  # POST /contact_sharing
  def create
    if current_member.update(member_params)
      redirect_to members_contact_sharing_path, notice: t('members.contact_sharings.flash.joined')
    else
      @depot = current_member.next_basket.depot
      render :show, status: :unprocessable_entity
    end
  end

  private

  def ensure_contact_sharing_feature
    redirect_to members_member_path unless Current.acp.feature?('contact_sharing')
  end

  def ensure_member_next_basket_presence
    redirect_to members_member_path unless current_member.next_basket
  end

  def member_params
    params
      .require(:member)
      .permit(:contact_sharing, :terms_of_service)
  end
end
