# frozen_string_literal: true

module Query
  class ExplainsController < BaseController
    def create
      render json: Runner.explain(params[:sql])
    end
  end
end
