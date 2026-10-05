# frozen_string_literal: true

module API
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :set_locale
      before_action :authenticate!

      private

      def set_locale
        params_locale = params[:locale]&.first(2)
        I18n.locale =
          (params_locale.in?(I18n.available_locales.map(&:to_s)) && params_locale) ||
          Current.org.languages.first
      end

      def authenticate!
        authenticate_or_request_with_http_token do |token, options|
          ActiveSupport::SecurityUtils.secure_compare(token, Current.org.api_token)
        end
      end
    end
  end
end
