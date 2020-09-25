module HasDeliveries
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :deliveries
    has_and_belongs_to_many :current_deliveries, -> { current_year },
      class_name: 'Delivery',
      after_add: :after_add_delivery!,
      after_remove: :after_remove_delivery!
    has_and_belongs_to_many :future_deliveries, -> { future_year },
      class_name: 'Delivery',
      after_add: :after_add_delivery!,
      after_remove: :after_remove_delivery!
  end

  def deliveries_count
    @deliveries_count ||= begin
      future_count = future_deliveries.count
      future_count.positive? ? future_count : current_deliveries.count
    end
  end

  def delivery_ids
    @delivery_ids ||= begin
      future_count = future_deliveries.count
      future_count.positive? ? future_deliveries.pluck(:id) : current_deliveries.pluck(:id)
    end
  end

  private

  def after_add_delivery!(_delivery)
    raise NotImplementedError
  end

  def after_remove_delivery!(_delivery)
    raise NotImplementedError
  end
end
