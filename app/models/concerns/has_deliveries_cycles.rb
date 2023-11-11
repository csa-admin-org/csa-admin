module HasDeliveriesCycles
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :deliveries_cycles,
      after_remove: :deliveries_cycles_removed!
    has_and_belongs_to_many :visibe_deliveries_cycles,
      -> { visible },
      class_name: 'DeliveriesCycle'

    validates :deliveries_cycles, presence: true

    after_commit :update_baskets_async, on: :update
  end

  def include_delivery?(delivery)
    deliveries_cycles.any? { |dc| dc.include_delivery?(delivery) }
  end

  def current_and_future_delivery_ids
    @current_and_future_delivery_ids ||=
      deliveries_cycles.map(&:current_and_future_delivery_ids).flatten.uniq
  end

  def next_delivery
    @next_delivery ||= coming_deliveries.first
  end

  def coming_deliveries
    @coming_deliveries ||=
      deliveries_cycles.map(&:coming_deliveries).flatten.uniq.sort_by(&:date)
  end

  def visible_deliveries_cycle_ids
    if visibe_deliveries_cycles.none?
      [main_deliveries_cycle.id]
    else
      visibe_deliveries_cycles.pluck(:id)
    end
  end

  def deliveries_counts(visible_only: true)
    if !visible_only
      deliveries_cycles.map(&:deliveries_count).uniq.sort
    elsif visibe_deliveries_cycles.none?
      [main_deliveries_cycle.deliveries_count]
    else
      visibe_deliveries_cycles.map(&:deliveries_count).uniq.sort
    end
  end

  def main_deliveries_cycle
    deliveries_cycles.max_by(&:deliveries_count)
  end

  private

  def deliveries_cycles_removed!(deliveries_cycle)
    @deliveries_cycles_removed ||= []
    @deliveries_cycles_removed << deliveries_cycle
  end

  def update_baskets_async
    return unless @deliveries_cycles_removed

    @deliveries_cycles_removed.uniq.each do |deliveries_cycle|
      DeliveriesCycleBasketsUpdaterJob.perform_later(deliveries_cycle)
    end
  end
end
