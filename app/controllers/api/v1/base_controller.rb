# frozen_string_literal: true

module API
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate!

      private

      def authenticate!
        authenticate_or_request_with_http_token do |token, options|
          ActiveSupport::SecurityUtils.secure_compare(token, Current.org.api_token)
        end
      end
    end
  end
end
