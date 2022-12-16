class Members::MembershipsController < Members::BaseController
  before_action :load_membership, only: %i[edit update]
  before_action :ensure_member_can_update_membership!, only: %i[edit update]

  # GET /memberships
  def index
    @membership = current_member.current_or_future_membership
    if @membership
      @membership.renewal_decision = :renew
    else
      redirect_to members_member_path
    end
  end

  # GET /memberships/:id/edit
  def edit
  end

  # PATCH /memberships/:id
  def update
    @membership.member_update!(membership_params)
    redirect_to members_memberships_path, notice: t('flash.actions.update.notice')
  end

  def load_membership
    @membership = current_member.memberships.find(params[:id])
  end

  def ensure_member_can_update_membership!
    redirect_to members_memberships_path unless @membership.can_member_update?
  end

  def membership_params
    params
      .require(:membership)
      .permit(:depot_id)
  end
end
