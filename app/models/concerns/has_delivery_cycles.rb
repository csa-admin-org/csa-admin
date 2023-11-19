module HasDeliveryCycles
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :delivery_cycles,
      after_remove: :delivery_cycles_removed!
    has_and_belongs_to_many :visibe_delivery_cycles,
      -> { visible },
      class_name: 'DeliveryCycle'

    validates :delivery_cycles, presence: true

    after_commit :update_baskets_async, on: :update
  end

  def include_delivery?(delivery)
    delivery_cycles.any? { |dc| dc.include_delivery?(delivery) }
  end

  def current_and_future_delivery_ids
    @current_and_future_delivery_ids ||=
      delivery_cycles.map(&:current_and_future_delivery_ids).flatten.uniq
  end

  def next_delivery
    @next_delivery ||= coming_deliveries.first
  end

  def coming_deliveries
    @coming_deliveries ||=
      delivery_cycles.map(&:coming_deliveries).flatten.uniq.sort_by(&:date)
  end

  def visible_delivery_cycle_ids
    if visibe_delivery_cycles.none?
      [main_delivery_cycle.id]
    else
      visibe_delivery_cycles.pluck(:id)
    end
  end

  def deliveries_counts
    if visibe_delivery_cycles.none?
      [main_delivery_cycle.deliveries_count]
    else
      visibe_delivery_cycles.map(&:deliveries_count).uniq.sort
    end
  end

  def main_delivery_cycle
    delivery_cycles.max_by(&:deliveries_count)
  end

  private

  def delivery_cycles_removed!(delivery_cycle)
    @delivery_cycles_removed ||= []
    @delivery_cycles_removed << delivery_cycle
  end

  def update_baskets_async
    return unless @delivery_cycles_removed

    @delivery_cycles_removed.uniq.each do |delivery_cycle|
      DeliveryCycleBasketsUpdaterJob.perform_later(delivery_cycle)
    end
  end
end
