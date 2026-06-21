# frozen_string_literal: true

module SessionRateLimiting
  extend ActiveSupport::Concern

  included do
    rate_limit to: 30, within: 10.minutes, only: :create,
      by: :rate_limit_session_ip, with: :rate_limit_exceeded, name: "create-ip"
    rate_limit to: 5, within: 15.minutes, only: :create,
      by: :rate_limit_session_email, with: :rate_limit_exceeded, name: "create-email"
    rate_limit to: 60, within: 10.minutes, only: :show,
      by: :rate_limit_session_ip, with: :rate_limit_exceeded, name: "redeem-ip"
  end

  private

  def rate_limit_session_ip
    request.remote_ip
  end

  def rate_limit_session_email
    params.dig(:session, :email).to_s.downcase.strip
  end

  def rate_limit_exceeded
    redirect_to({ action: :new }, alert: t("sessions.flash.rate_limited"))
  end
end
