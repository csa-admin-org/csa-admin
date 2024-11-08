# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :set_locale

  around_action :n_plus_one_detection, if: -> { Rails.env.development? }

  helper_method :current_admin, :current_session

  rescue_from ActiveRecord::InvalidForeignKey do
    redirect_back(
      fallback_location: root_path,
      alert: t("active_admin.flash.invalid_foreign_key_alert"))
  end

  def access_denied(exception)
    redirect_back fallback_location: root_path, alert: exception.message
  end

  private

  def authenticate_admin!
    if !current_admin
      cookies.delete(:session_id)
      redirect_to login_path, alert: t("sessions.flash.required")
    elsif current_session&.expired?
      cookies.delete(:session_id)
      redirect_to login_path, alert: t("sessions.flash.expired")
    else
      set_appsignal_tags
      update_last_usage(current_session)
    end
  end

  def current_admin
    auto_sign_in_admin_in_dev || current_session&.admin
  end

  def auto_sign_in_admin_in_dev
    return unless Rails.env.development?
    return unless ENV["AUTO_SIGN_IN_ADMIN_EMAIL"]

    admin = Admin.find_by!(email: ENV["AUTO_SIGN_IN_ADMIN_EMAIL"])
    if current_session&.admin == admin
      return admin
    end

    session = create_session!(admin)
    cookies.encrypted.permanent[:session_id] = session.id
    session.admin
  end

  def current_session
    Current.session ||= session_id && Session.usable.find_by(id: session_id)
  end

  def session_id
    cookies.encrypted[:session_id]
  end

  def set_locale
    params_locale = params[:locale]&.first(2)
    I18n.locale =
      (params_locale.in?(I18n.available_locales.map(&:to_s)) && params_locale) ||
      current_admin&.language ||
      Current.org.languages.first
  end

  def update_last_usage(session)
    return if session.last_used_at && session.last_used_at > 1.hour.ago

    session.update_columns(
      last_used_at: Time.current,
      last_remote_addr: request.remote_addr,
      last_user_agent: request.env.fetch("HTTP_USER_AGENT", "-"))
  end

  def set_appsignal_tags
    Appsignal.add_tags(
      id: "admin_#{current_admin.id}",
      session_id: current_session.id)
  end

  def create_session_from_devise_remember_token!
    admin = ::Admin.find(cookies.signed[:remember_admin_token].first.first)
    create_session!(admin)
  end

  def create_session!(admin)
    Session.create!(
      remote_addr: request.remote_addr,
      user_agent: request.env.fetch("HTTP_USER_AGENT", "-"),
      admin_email: admin.email)
  end

  # https://github.com/charkost/prosopite?tab=readme-ov-file#development-environment-usage
  def n_plus_one_detection
    Prosopite.scan
    yield
  ensure
    Prosopite.finish
  end
end
