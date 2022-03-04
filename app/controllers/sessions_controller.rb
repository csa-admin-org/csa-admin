require 'bcrypt'

class SessionsController < ApplicationController
  helper ActiveAdmin::ViewHelpers
  layout false

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
        session_url: session_url(@session.token)
      ).new_admin_session_email.deliver_later
      I18n.locale = @session.admin.language
      redirect_to login_path(locale: I18n.locale), notice: t('sessions.flash.initiated')
    else
      render :new
    end
  end

  # GET /sessions/:id
  def show
    # Make it "slow" on purpose to make brute-force attacks more of a hassle
    BCrypt::Password.create(params[:id])

    @session = Session.find_by!(token: params[:id])

    if !@session.timeout?
      cookies.encrypted.permanent[:session_id] = @session.id
      redirect_to root_path, notice: t('sessions.flash.created')
    elsif current_admin&.id == @session.admin_id
      redirect_to root_path, notice: t('sessions.flash.already_exists')
    else
      redirect_to login_path, alert: t('sessions.flash.timeout')
    end
  end

  # DELETE /logout
  def destroy
    cookies.delete(:session_id)
    redirect_to login_path, notice: t('sessions.flash.deleted')
  end
end
