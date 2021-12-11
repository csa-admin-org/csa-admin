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
          basket_sizes: basket_sizes_json,
          depots: depots_json,
          vegetables: @vegetable.select(:id, :names)
        }
      end

      def basket_sizes_json
        @basket_sizes
          .select(:id, :public_names, :names, :visible)
          .map { |basket_size|
            basket_size
              .as_json(only: %i[id visible])
              .merge(names: Current.acp.languages.map { |l| [l, basket_size.public_name] }.to_h)
          }

      end

      def depots_json
        @depots
          .select(:id, :public_names, :name, :visible)
          .map { |depot|
            depot
              .as_json(only: %i[id visible])
              .merge(names: Current.acp.languages.map { |l| [l, depot.public_name] }.to_h)
          }
      end
    end
  end
end
