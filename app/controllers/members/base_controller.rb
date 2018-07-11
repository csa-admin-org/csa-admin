class Members::BaseController < ApplicationController
  layout 'members'
  before_action :set_locale
  before_action :authenticate_member!

  helper_method :current_member

  private

  def authenticate_member!
    return if current_member
    redirect_to members_login_path, alert: t('members.flash.authentication_required')
  end

  def current_member
    return @current_member if @current_member
    session_id = cookies.encrypted[:session_id]
    return unless session_id

    session = Session.find_by(id: session_id)
    if session.expired?
      cookies.delete(:session_id)
      redirect_to members_login_path, alert: t('members.flash.session_expired')
    else
      update_last_usage(session)
      @current_member = session.member
    end
  end

  def set_locale
    cookies.permanent[:locale] = params[:locale] if params.key?(:locale)
    I18n.locale =
      cookies[:locale] ||
      current_member&.language ||
      Current.acp.languages.first
  end

  def update_last_usage(session)
    return if session.last_used_at && session.last_used_at > 1.hour.ago

    session.update_columns(
      last_used_at: Time.current,
      last_remote_addr: request.remote_addr,
      last_user_agent: request.env['HTTP_USER_AGENT'])
  end
end
