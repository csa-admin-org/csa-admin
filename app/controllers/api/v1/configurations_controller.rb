module API
  module V1
    class ConfigurationsController < BaseController
      def show
        @basket_sizes = BasketSize.all
        @depots = Depot.used.all
        @vegetable = Vegetable.all

        if stale?(cache_object)
          render json: payload
        end
      end

      private

      def cache_object
        updated_at = [
          @basket_sizes,
          @depots,
          @vegetable
        ].map { |k| k.maximum(:updated_at) }.compact.max
        OpenStruct.new(updated_at: updated_at)
      end

      def payload
        {
          basket_sizes: @basket_sizes.select(:id, :names),
          depots: depots_json,
          vegetables: @vegetable.select(:id, :names)
        }
      end

      def depots_json
        @depots
          .select(:id, :form_names, :name, :visible)
          .as_json(only: %i[id visible], methods: :names)
      end
    end
  end
end
