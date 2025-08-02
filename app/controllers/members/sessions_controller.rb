# frozen_string_literal: true

require "bcrypt"

class Members::SessionsController < Members::BaseController
  layout "members"
  skip_before_action :authenticate_member!

  # GET /login
  def new
    redirect_to members_member_path if current_member
    @session = Session.new
  end

  # POST /sessions
  def create
    @session = Session.new(
      member_email: params.require(:session)[:email],
      request: request)

    if @session.save
      SessionMailer.with(
        session: @session,
        session_url: members_session_url(@session.generate_token_for(:redeem), locale: @session.member.language)
      ).new_member_session_email.deliver_later(queue: :critical)
      I18n.locale = @session.member.language
      redirect_to members_login_path(locale: I18n.locale), notice: t("sessions.flash.initiated")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sessions/:id
  def show
    if @session = Session.find_by_token_for(:redeem, params[:id])
      cookies.encrypted.permanent[:session_id] = @session.id
      redirect_to members_member_path, notice: t("sessions.flash.created")
    else
      redirect_to members_login_path, alert: t("sessions.flash.invalid")
    end
  end

  # DELETE /logout
  def destroy
    current_session&.revoke!
    cookies.delete(:session_id)
    redirect_to members_login_path, notice: t("sessions.flash.deleted")
  end
end
