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
              quantities: content.basket_size_ids.map { |basket_size_id|
                {
                  basket_size_id: basket_size_id,
                  quantity: content.basket_quantity(basket_size_id).to_f
                }
              },
              depot_ids: content.depot_ids.sort
            }
          }
        }
      end
    end
  end
end
