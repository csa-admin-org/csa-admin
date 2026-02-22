# frozen_string_literal: true

class Members::DeletionConfirmationsController < Members::BaseController
  before_action :ensure_discardable!, only: :create

  def new
  end

  def create
    if DeletionCode.verify(current_session, params[:code])
      current_member.discard!
      cookies.delete(:session_id)

      redirect_to members_public_page_path("goodbye")
    else
      current_session.touch(:updated_at)
      redirect_to new_members_account_deletion_request_path, alert: t(".flash.invalid_code")
    end
  end

  private

  def ensure_discardable!
    unless current_member.can_discard?
      redirect_to new_members_account_deletion_request_path, alert: t("members.deletion_requests.new.not_eligible")
    end
  end
end
