# frozen_string_literal: true

class Notification::BasketComplementDeliveryCount < Notification::Base
  def notify
    basket_complements_by_days_before.each do |days_before, complements|
      target_date = Date.current + days_before.days
      complement_ids = complements.map(&:id)

      Delivery.where(date: target_date).each do |delivery|
        delivery.basket_complements.where(id: complement_ids).each do |complement|
          count = BasketComplementCount.new(complement, delivery).count
          next unless count.positive?

          BasketComplementMailer.with(
            basket_complement: complement,
            delivery: delivery,
            count: count
          ).delivery_count_email.deliver_later
        end
      end
    end
  end

  private

  def basket_complements_by_days_before
    BasketComplement.kept.select(&:emails?).group_by(&:notify_days_before_delivery)
  end
end
