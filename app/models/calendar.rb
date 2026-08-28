# frozen_string_literal: true

class Calendar
  Day = Data.define(
    :date,
    :delivery,
    :special_delivery,
    :activity_ids,
    :baskets_count,
    :shop_orders_count,
    :participants_count
  ) do
    def past? = date < Date.current
    def today? = date.today?
    def coming? = date >= Date.current
    def delivery? = delivery.present?
    def shop?
      return false unless Current.org.feature?("shop")

      special_delivery.present? || (delivery? && delivery.shop_open)
    end
    def activity? = activity_ids.any?
    def busy? = delivery? || special_delivery.present? || activity?
    def event? = coming? && busy?
    def show_baskets? = baskets_count.positive?
    def show_shop? = shop? && shop_orders_count.positive?
    def show_activity? = participants_count.positive?
    def show_counts? = busy? && (show_baskets? || show_shop? || show_activity?)
    def shop_delivery = delivery || special_delivery
  end

  def initialize(today = Date.current)
    @range = today.beginning_of_week..today.next_week.end_of_week
    @shop = Current.org.feature?("shop")
    @activity = Current.org.feature?("activity")
    @deliveries = Delivery.between(@range).index_by(&:date)
    @special_deliveries = @shop ? Shop::SpecialDelivery.between(@range).index_by(&:date) : {}
    @activities_by_date = @activity ? activities_by_date : {}
    @baskets_by_date = baskets_by_date
    @shop_orders_by_date = @shop ? shop_orders_by_date : {}
    @participants_by_date = @activity ? participants_by_date : {}
  end

  def present?
    days.any?(&:busy?)
  end

  def days
    @days ||= @range.map { |date| build_day(date) }
  end

  private

  def build_day(date)
    activity_ids = @activities_by_date.fetch(date, [])
    Day.new(
      date: date,
      delivery: @deliveries[date],
      special_delivery: @special_deliveries[date],
      activity_ids: activity_ids,
      baskets_count: @baskets_by_date[date] || 0,
      shop_orders_count: @shop_orders_by_date[date] || 0,
      participants_count: @participants_by_date[date] || 0)
  end

  def activities_by_date
    Activity.between(@range).pluck(:date, :id).each_with_object(Hash.new { |h, k| h[k] = [] }) { |(date, id), hash|
      hash[date.to_date] << id
    }
  end

  def baskets_by_date
    date_counts(
      Basket.active.between(@range).joins(:delivery).group("deliveries.date").sum(:quantity))
  end

  def participants_by_date
    date_counts(
      ActivityParticipation.not_rejected.between(@range).joins(:activity).group("activities.date").sum(:participants_count))
  end

  def shop_orders_by_date
    records = (@deliveries.values + @special_deliveries.values).index_by { |d| [ d.class.name, d.id ] }
    return {} if records.empty?

    Shop::Order.all_without_cart.where(delivery: records.values)
      .group(:delivery_type, :delivery_id).count
      .each_with_object(Hash.new(0)) { |((type, id), count), hash|
        hash[records[[ type, id ]].date] += count
      }
  end

  def date_counts(grouped)
    grouped.each_with_object({}) { |(date, count), hash|
      hash[date.to_date] = count
    }
  end
end
