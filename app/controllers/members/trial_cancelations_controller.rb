# frozen_string_literal: true

class Members::TrialCancelationsController < Members::BaseController
  before_action :load_membership
  before_action :ensure_can_cancel_trial!

  def new
  end

  def create
    if @membership.cancel_trial!(cancelation_params)
      redirect_to members_memberships_path, notice: t(".flash.notice")
    else
      redirect_to members_memberships_path, alert: t(".flash.alert")
    end
  end

  private

  def load_membership
    @membership = current_member.current_or_future_membership
    raise ActiveRecord::RecordNotFound unless @membership
  end

  def ensure_can_cancel_trial!
    return if @membership.can_member_cancel_trial?

    redirect_to members_memberships_path
  end

  def cancelation_params
    params.require(:membership).permit(:renewal_note, :renewal_annual_fee)
  end
end
