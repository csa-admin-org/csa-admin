# frozen_string_literal: true

module SessionTracking
  extend ActiveSupport::Concern

  SESSION_COOKIE = :session_id

  included do
    helper_method :current_session
  end

  private

  def current_session
    Current.session ||= session_id && Session.usable.find_by(id: session_id)
  end

  def session_id
    cookies.encrypted[SESSION_COOKIE]
  end

  def sign_in_session(session)
    cookies.encrypted[SESSION_COOKIE] = session_cookie(session)
  end

  def sign_out_session
    current_session&.revoke!
    delete_session_cookie
  end

  def delete_session_cookie
    cookies.delete(SESSION_COOKIE, path: "/")
  end

  def session_cookie(session)
    {
      value: session.id,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      path: "/"
    }
  end

  def update_last_usage(session)
    return if session.last_used_at && session.last_used_at > 1.hour.ago

    session.update_columns(
      last_used_at: Time.current,
      last_remote_addr: request.remote_addr,
      last_user_agent: request.env.fetch("HTTP_USER_AGENT", "-"))
  end
end
