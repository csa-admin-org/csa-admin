# frozen_string_literal: true

class Members::DeletionRequestsController < Members::BaseController
  before_action :ensure_discardable!, only: :create

  def new
  end

  def create
    current_session.rotate_deletion_code!
    SessionMailer.with(
      session: current_session
    ).deletion_confirmation_email.deliver_later(queue: :critical)

    redirect_to new_members_account_deletion_confirmation_path
  end

  private

  def ensure_discardable!
    unless current_member.can_discard?
      redirect_to new_members_account_deletion_request_path, alert: t("members.deletion_requests.new.not_eligible")
    end
  end
end
