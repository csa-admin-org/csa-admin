# frozen_string_literal: true

module SessionTracking
  extend ActiveSupport::Concern

  included do
    helper_method :current_session
  end

  private

  def current_session
    Current.session ||= session_id && Session.usable.find_by(id: session_id)
  end

  def session_id
    cookies.encrypted[:session_id]
  end

  def update_last_usage(session)
    return if session.last_used_at && session.last_used_at > 1.hour.ago

    session.update_columns(
      last_used_at: Time.current,
      last_remote_addr: request.remote_addr,
      last_user_agent: request.env.fetch("HTTP_USER_AGENT", "-"))
  end
end
