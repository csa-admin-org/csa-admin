# frozen_string_literal: true

module Query
  class TicketSearchesController < BaseController
    def create
      render json: TicketSearch.run(
        params[:q],
        token: query_token,
        per: params[:per],
        tenants: params[:tenant].presence || params[:tenants])
    end
  end
end
