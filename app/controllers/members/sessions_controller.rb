# frozen_string_literal: true

require "bcrypt"

class Members::SessionsController < Members::BaseController
  include CapVerifiable
  include SessionRateLimiting
  include MagicLinkReferrerPolicy

  layout "members"
  skip_before_action :authenticate_member!

  def new
    if current_member
      flash.now[:alert] ||= t("members.sessions.flash.other_account")
    end
    @session = Session.new
  end

  def create
    if current_member
      redirect_to members_login_path, alert: t("members.sessions.flash.other_account")
      return
    end

    @session = Session.new(
      member_email: params.require(:session)[:email],
      request: request)

    if @session.save
      @session.deliver_login_email!
      redirect_to members_login_path, notice: t("sessions.flash.initiated")
    elsif @session.errors.added?(:email, :suppressed)
      redirect_to members_login_path, alert: t("members.sessions.flash.suppressed")
    elsif @session.masked_login_error?
      redirect_to members_login_path, notice: t("sessions.flash.initiated")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    return head :ok if request.head?

    if current_member && other_member_login_token?
      redirect_to members_login_path, alert: t("members.sessions.flash.other_account")
    elsif @session = Session.redeem_token(params[:id], owner_type: :member)
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

  def other_member_login_token?
    token_session = Session.find_by_token_for(:redeem, params[:id]) ||
      Session.find_by_token_for(:demo_invite, params[:id])
    return false unless token_session&.redeemable_as?(:member)
    return false if token_session.admin_originated?

    token_session.member_id != current_member.id
  end

  def allow_admin_originated_session_write?
    action_name == "destroy"
  end

  def cap_after_failure
    @session = Session.new
    flash.now[:alert] = t("cap.failed_retry")
    render :new, status: :unprocessable_entity
  end
end
