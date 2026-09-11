# frozen_string_literal: true

module Query
  class CatalogController < BaseController
    def show
      render json: {
        routes: Catalog::ROUTES,
        tenants: query_token.catalog_tenants
      }
    end
  end
end
