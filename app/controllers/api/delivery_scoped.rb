# frozen_string_literal: true

module API
  # Provides delivery lookup for API endpoints that operate on a specific delivery.
  # Supports numeric IDs as well as "current" and "next" keywords.
  #
  # Usage:
  #   class BasketsController < BaseController
  #     include DeliveryScoped
  #
  #     def index
  #       @baskets = @delivery.baskets
  #     end
  #   end
  #
  # Routes:
  #   GET /api/v1/deliveries/123/baskets
  #   GET /api/v1/deliveries/current/baskets
  #   GET /api/v1/deliveries/next/baskets
  module DeliveryScoped
    extend ActiveSupport::Concern

    included do
      before_action :set_delivery
    end

    private

    def set_delivery
      @delivery =
        case params[:delivery_id]
        when "current"
          Delivery.current
        when "next"
          Delivery.next
        else
          Delivery.find_by(id: params[:delivery_id])
        end

      head :not_found unless @delivery
    end
  end
end
