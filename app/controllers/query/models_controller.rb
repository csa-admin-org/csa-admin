# frozen_string_literal: true

module Query
  class ModelsController < BaseController
    def show
      render json: Runner.models
    end
  end
end
