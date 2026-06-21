# frozen_string_literal: true

require "bcrypt"

class SessionsController < ApplicationController
  include CapVerifiable
  include SessionRateLimiting
  include MagicLinkReferrerPolicy

  helper ActiveAdmin::LayoutHelper
  layout "active_admin_logged_out"

  def new
    redirect_to root_path if current_admin
    @session = Session.new
  end

  def create
    @session = Session.new(
      admin_email: params.require(:session)[:email],
      request: request)

    if @session.save
      SessionMailer.with(
        session: @session,
        session_url: session_url(@session.generate_token_for(:redeem))
      ).new_admin_session_email.deliver_later(queue: :critical)
      redirect_to login_path, notice: t("sessions.flash.initiated")
    elsif @session.masked_login_error?
      redirect_to login_path, notice: t("sessions.flash.initiated")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    if @session = Session.redeem_token(params[:id], owner_type: :admin)
      sign_in_session(@session)
      redirect_to root_path, notice: t("sessions.flash.created")
    else
      redirect_to login_path, alert: t("sessions.flash.invalid")
    end
  end

  def destroy
    sign_out_session
    redirect_to login_path, notice: t("sessions.flash.deleted")
  end

  private

  def cap_after_failure
    @session = Session.new
    flash.now[:alert] = t("cap.failed_retry")
    render :new, status: :unprocessable_entity
  end
end
