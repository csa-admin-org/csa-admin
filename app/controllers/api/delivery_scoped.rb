# frozen_string_literal: true

module API
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
