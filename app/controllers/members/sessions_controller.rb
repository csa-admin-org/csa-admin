# frozen_string_literal: true

require "bcrypt"

class Members::SessionsController < Members::BaseController
  include CapVerifiable
  include SessionRateLimiting
  include MagicLinkReferrerPolicy

  layout "members"
  skip_before_action :authenticate_member!

  def new
    redirect_to members_member_path if current_member
    @session = Session.new
  end

  def create
    @session = Session.new(
      member_email: params.require(:session)[:email],
      request: request)

    if @session.save
      SessionMailer.with(
        session: @session,
        session_url: members_session_url(@session.generate_token_for(:redeem), locale: @session.member.language)
      ).new_member_session_email.deliver_later(queue: :critical)
      redirect_to members_login_path, notice: t("sessions.flash.initiated")
    elsif @session.masked_login_error?
      redirect_to members_login_path, notice: t("sessions.flash.initiated")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    return head :ok if request.head?

    if @session = Session.redeem_token(params[:id], owner_type: :member)
      sign_in_session(@session)
      redirect_to members_member_path, notice: t("sessions.flash.created")
    else
      redirect_to members_login_path, alert: t("sessions.flash.invalid")
    end
  end

  def destroy
    sign_out_session
    redirect_to members_login_path, notice: t("sessions.flash.deleted")
  end

  private

  def allow_admin_originated_session_write?
    action_name == "destroy"
  end

  def cap_after_failure
    @session = Session.new
    flash.now[:alert] = t("cap.failed_retry")
    render :new, status: :unprocessable_entity
  end
end
