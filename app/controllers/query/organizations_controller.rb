# frozen_string_literal: true

module Query
  class OrganizationsController < BaseController
    def index
      render json: OrganizationsIndex.run(
        token: query_token,
        attributes: params[:attributes],
        tenants: params[:tenant].presence || params[:tenants],
        filters: fleet_filters)
    end

    private

    def fleet_filters
      params.except(
        :controller, :action, :format, :subdomain,
        :attributes, :tenant, :tenants).to_unsafe_h
    end
  end
end
