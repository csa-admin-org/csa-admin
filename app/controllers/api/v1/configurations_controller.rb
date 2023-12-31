module API
  module V1
    class ConfigurationsController < BaseController
      def show
        @basket_sizes = BasketSize.all
        @depots = Depot.used.all
        @basket_content_products = BasketContent::Product.all

        if stale?(cache_object)
          render json: payload
        end
      end

      private

      def cache_object
        updated_at = [
          @basket_sizes,
          @depots,
          @basket_content_products
        ].map { |k| k.maximum(:updated_at) }.compact.max
        OpenStruct.new(updated_at: updated_at)
      end

      def payload
        {
          basket_sizes: basket_sizes_json,
          depots: depots_json,
          basket_content_products: @basket_content_products.select(:id, :names).map { |product|
            product
              .as_json(only: %i[id])
              .merge(names: all_locales { |l| [ l, product.name ] })
          }
        }
      end

      def basket_sizes_json
        @basket_sizes
          .select(:id, :public_names, :names, :visible)
          .map { |basket_size|
            basket_size
              .as_json(only: %i[id visible])
              .merge(names: all_locales { |l| [ l, basket_size.public_name ] })
          }
      end

      def depots_json
        @depots
          .select(:id, :public_names, :name, :visible)
          .map { |depot|
            depot
              .as_json(only: %i[id visible])
              .merge(names: all_locales { |l| [ l, depot.public_name ] })
          }
      end

      def all_locales
        Current.acp.languages.map { |l|
          I18n.with_locale(l) { yield(l) }
        }.to_h
      end
    end
  end
end
