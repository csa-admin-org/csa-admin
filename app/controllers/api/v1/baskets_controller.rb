# frozen_string_literal: true

module API
  module V1
    class BasketsController < BaseController
      include DeliveryScoped

      # GET /api/v1/deliveries/:delivery_id/baskets.csv
      #
      # Returns basket CSV for the specified delivery.
      # Supports "current", "next", or a numeric delivery ID.
      def index
        exporter = Basket::CSVExporter.new(delivery: @delivery)

        send_data exporter.generate,
          filename: exporter.filename,
          type: "text/csv; charset=utf-8"
      end
    end
  end
end
