# frozen_string_literal: true

module Query
  class SchemasController < BaseController
    def show
      render json: Runner.schema(params[:table])
    end
  end
end
