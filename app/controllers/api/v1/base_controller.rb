module API
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate!

      private

      def authenticate!
        authenticate_or_request_with_http_token do |token, options|
          api_token = Current.acp.credentials(:api_token)
          api_token && ActiveSupport::SecurityUtils.secure_compare(token, api_token)
        end
      end
    end
  end
end
