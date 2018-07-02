class Members::BaseController < ApplicationController
  layout 'members'
  before_action :authenticate_member!
  before_action :set_locale

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
      @current_member = session.member
    end
  end

  def set_locale
    I18n.locale = params[:locale] ||
      current_member&.language ||
      I18n.default_locale
  end
end
