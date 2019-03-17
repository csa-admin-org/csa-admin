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
      update_last_usage(current_session)
    end
  end
end
