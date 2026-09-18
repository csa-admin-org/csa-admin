# frozen_string_literal: true

module Query
  class BankConnectionsController < BaseController
    def index
      render json: BankConnectionsIndex.run(
        token: query_token,
        tenants: params[:tenant].presence || params[:tenants],
        filters: fleet_filters)
    end

    private

    def fleet_filters
      params.except(
        :controller, :action, :format, :subdomain,
        :tenant, :tenants, :attributes).to_unsafe_h
    end
  end
end
