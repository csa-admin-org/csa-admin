require "bcrypt"

class Members::NewsletterSubscriptionsController < Members::BaseController
  layout "members"
  skip_before_action :authenticate_member!
  before_action :ensure_valid_token

  # POST /newsletters/subscribe/:token
  def create
    EmailSuppression.unsuppress!(email,
      stream_id: "broadcast",
      origin: "Customer")
  end

  # GET /newsletters/unsubscribe/:token
  def destroy
    EmailSuppression.suppress!(email,
      stream_id: "broadcast",
      reason: "ManualSuppression",
      origin: "Customer")
  end

  private

  def email
    @email ||= Newsletter::Audience.decrypt_email(params[:token])
  end
  helper_method :email

  def member
    @member ||= Member.find_by_email(email)
  end

  def current_member; nil end

  def ensure_valid_token
    unless member
      render :invalid, status: :not_found
    end
  end
end
