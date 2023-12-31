class Members::EmailSuppressionsController < Members::BaseController
  before_action :ensure_non_admin_originated_session!

  # DELETE /email_suppression
  def destroy
    email = current_session.email
    EmailSuppression.unsuppress!(email, stream_id: "broadcast")

    redirect_to members_account_path, notice: t(".flash.notice")
  end

  private

  def ensure_non_admin_originated_session!
    if current_session.admin_originated?
      redirect_to members_account_path
    end
  end
end
