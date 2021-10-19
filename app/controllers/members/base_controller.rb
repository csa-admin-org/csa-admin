class Members::BaseController < ApplicationController
  layout 'members'
  before_action :authenticate_member!

  helper_method :current_member

  private

  def authenticate_member!
    if !current_member
      cookies.delete(:session_id)
      redirect_to members_login_path, alert: t('sessions.flash.required')
    elsif current_session&.expired?
      cookies.delete(:session_id)
      redirect_to members_login_path, alert: t('sessions.flash.expired')
    else
      set_sentry_user
      update_last_usage(current_session)
    end
  end

  def current_member
    current_session&.member
  end

  def set_locale
    if params[:locale].in?(Current.acp.languages)
      cookies.permanent[:locale] = params[:locale]
    end
    unless cookies[:locale].in?(Current.acp.languages)
      cookies.delete(:locale)
    end
    I18n.locale =
      current_member&.language ||
      cookies[:locale] ||
      Current.acp.languages.first
  end

  def set_sentry_user
    Sentry.set_user(
      id: "member_#{current_member.id}",
      session_id: current_session.id)
  end
end
