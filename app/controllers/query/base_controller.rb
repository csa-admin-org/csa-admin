# frozen_string_literal: true

module Query
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    wrap_parameters false

    attr_reader :query_token

    before_action :load_token
    rate_limit to: 60, within: 1.minute, by: -> { rate_limit_key },
      with: -> { render_auth_error("rate_limited", :too_many_requests) }
    before_action :authenticate!
    around_action :switch_tenant, if: :tenant_param?

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from Query::Error, with: :render_query_error

    private

    def load_token
      authenticate_with_http_token do |raw, _options|
        @query_token = Query::Token.authenticate(raw)
        query_token.present?
      end
    end

    def authenticate!
      render_auth_error("unauthorized", :unauthorized) unless query_token
    end

    def tenant_param?
      params[:tenant].present?
    end

    def switch_tenant
      slug = params[:tenant].to_s
      unless Tenant.exists?(slug) && query_token.allows?(slug)
        render_auth_error("not_found", :not_found)
        return
      end

      Tenant.switch(slug) { yield }
    end

    def rate_limit_key
      if query_token
        "query:#{query_token.name}"
      else
        "query-ip:#{request.remote_ip}"
      end
    end

    def render_not_found
      render_auth_error("not_found", :not_found)
    end

    def render_auth_error(code, status)
      render json: { error: code }, status: status
    end

    def render_query_error(error)
      if error.message == "not_found"
        render_auth_error("not_found", :not_found)
      else
        render json: { error: error.message, meta: { query_time_ms: 0 } }, status: :bad_request
      end
    end
  end
end
