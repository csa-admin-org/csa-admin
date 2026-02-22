# frozen_string_literal: true

module API
  module V1
    class BasketsController < BaseController
      include DeliveryScoped

      def index
        exporter = Basket::CSVExporter.new(delivery: @delivery)

        send_data exporter.generate,
          filename: exporter.filename,
          type: "text/csv; charset=utf-8"
      end
    end
  end
end
