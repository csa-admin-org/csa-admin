# frozen_string_literal: true

class Members::MembershipsController < Members::BaseController
  before_action :load_membership, only: %i[edit update]
  before_action :ensure_member_can_update_membership!, only: %i[edit update]

  def index
    @membership = current_member.closest_membership
    if @membership
      @membership.renewal_decision = :renew
    else
      redirect_to members_member_path
    end
  end

  def edit
  end

  def update
    @membership.member_update!(membership_params)
    redirect_to members_memberships_path, notice: t("flash.actions.update.notice")
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
