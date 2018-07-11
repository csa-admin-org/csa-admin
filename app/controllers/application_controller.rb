class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :prepare_exception_notifier
  before_action :set_locale

  def access_denied(exception)
    redirect_to root_path, alert: exception.message
  end

  private

  def set_locale
    I18n.locale =
      params[:locale] ||
      current_admin&.language ||
      Current.acp.languages.first
  end

  def prepare_exception_notifier
    request.env['exception_notifier.exception_data'] = {
      current_acp: Apartment::Tenant.current
    }
  end
end
