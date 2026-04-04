# frozen_string_literal: true

class Notification::BasketComplementWeeklySummary < Notification::Base
  def notify
    return if week_deliveries.none?

    BasketComplement.kept.select(&:emails?).each do |complement|
      deliveries_counts = week_deliveries_counts_for(complement)
      next if deliveries_counts.empty?

      BasketComplementMailer.with(
        basket_complement: complement,
        deliveries_counts: deliveries_counts
      ).weekly_summary_email.deliver_later
    end
  end

  private

  def week_deliveries
    @week_deliveries ||= Delivery.between(1.week.from_now.all_week)
  end

  def week_deliveries_counts_for(complement)
    week_deliveries.filter_map { |delivery|
      next unless delivery.basket_complements.include?(complement)

      count = BasketComplementCount.new(complement, delivery).count
      { delivery: delivery, count: count } if count.positive?
    }
  end
end
