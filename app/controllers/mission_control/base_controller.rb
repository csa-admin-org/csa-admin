# frozen_string_literal: true

class MissionControl::BaseController < ApplicationController
  skip_before_action :set_locale
  skip_before_action :capture_promotion
  skip_around_action :set_time_zone

  layout "mission_control"

  http_basic_authenticate_with \
    name: Rails.application.credentials.dig(:mission_control, :http_basic_auth_user),
    password: Rails.application.credentials.dig(:mission_control, :http_basic_auth_password),
    if: -> { !Rails.env.development? }

  before_action :set_mc_locale

  private

  def set_mc_locale
    I18n.locale = I18n.default_locale
  end

  # MC hosts stay outside tenant SQLite; never resolve a session cookie here.
  def current_session
    nil
  end
end
