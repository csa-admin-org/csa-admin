# frozen_string_literal: true

require "ostruct"

module API
  module V1
    class BasketContentsController < BaseController
      def index
        @delivery = Delivery.current
        @basket_contents = @delivery.basket_contents.includes(:depots)

        if stale?(cache_object)
          render json: payload
        end
      end

      private

      def cache_object
        updated_at = @basket_contents.maximum(:updated_at)
        OpenStruct.new(updated_at: updated_at)
      end

      def payload
        {
          delivery: @delivery.as_json(only: [ :id, :date ]),
          products: @basket_contents.map { |content|
            {
              id: content.product_id,
              unit: content.unit,
              quantities: quantities_for(content),
              depot_ids: content.depot_ids.sort
            }
          }
        }
      end

      def quantities_for(content)
        content.basket_quantities
          .sort_by { |id, _| basket_size_ids_order.index(id.to_i) || basket_size_ids_order.size }
          .map { |id, qty|
            {
              basket_size_id: id.to_i,
              quantity: qty.to_f
            }
          }
      end

      def basket_size_ids_order
        @basket_size_ids_order ||= BasketSize.ordered.paid.pluck(:id)
      end
    end
  end
end
