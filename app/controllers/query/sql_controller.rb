# frozen_string_literal: true

module Query
  class SqlController < BaseController
    def create
      render json: Runner.sql(
        params[:sql],
        page: params[:page],
        per: params[:per])
    end
  end
end
