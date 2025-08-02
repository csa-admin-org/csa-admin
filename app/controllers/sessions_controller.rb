# frozen_string_literal: true

require "bcrypt"

class SessionsController < ApplicationController
  # helper ActiveAdmin::ViewHelpers
  helper ActiveAdmin::LayoutHelper
  layout "active_admin_logged_out"

  # GET /login
  def new
    redirect_to root_path if current_admin
    @session = Session.new
  end

  # POST /sessions
  def create
    @session = Session.new(
      admin_email: params.require(:session)[:email],
      request: request)

    if @session.save
      SessionMailer.with(
        session: @session,
        session_url: session_url(@session.generate_token_for(:redeem))
      ).new_admin_session_email.deliver_later(queue: :critical)
      I18n.locale = @session.admin.language
      redirect_to login_path(locale: I18n.locale), notice: t("sessions.flash.initiated")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sessions/:id
  def show
    if @session = Session.find_by_token_for(:redeem, params[:id])
      cookies.encrypted.permanent[:session_id] = @session.id
      redirect_to root_path, notice: t("sessions.flash.created")
    else
      redirect_to login_path, alert: t("sessions.flash.invalid")
    end
  end

  # DELETE /logout
  def destroy
    current_session&.revoke!
    cookies.delete(:session_id)
    redirect_to login_path, notice: t("sessions.flash.deleted")
  end
end
