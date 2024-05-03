class Newsletter
  class DeliveryProcessJob < ApplicationJob
    queue_as :low

    def perform(delivery)
      delivery.process!
    end
  end
end
