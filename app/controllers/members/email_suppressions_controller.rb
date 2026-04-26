# frozen_string_literal: true

class Members::EmailSuppressionsController < Members::BaseController
  def destroy
    email = current_session.email
    EmailSuppression.unsuppress!(email, stream_id: "broadcast")

    redirect_to members_newsletter_deliveries_path, notice: t(".flash.notice")
  end
end
