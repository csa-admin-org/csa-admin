class Newsletter
  class DeliveryJob < ApplicationJob
    queue_as :default

    def perform(newsletter)
      newsletter.deliveries.undelivered.find_each(&:deliver!)
    end
  end
end
