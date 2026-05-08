# frozen_string_literal: true

class Notification::AdminDeliveryList < Notification::Base
  def notify
    notify_admins
    notify_depots
  end

  private

  def notify_admins
    tomorrow_deliveries.each do |delivery|
      Admin.notify!(:delivery_list, delivery: delivery)
    end
  end

  def notify_depots
    depots_by_days_before.each do |days_before, depots|
      target_date = Date.current + days_before.days
      depot_ids = depots.map(&:id)

      Delivery.where(date: target_date).each do |delivery|
        delivery.depots.where(id: depot_ids).each do |depot|
          DepotMailer.with(
            depot: depot,
            delivery: delivery
          ).delivery_list_email.deliver_later
        end
      end
    end
  end

  def tomorrow_deliveries
    Delivery.where(date: Date.tomorrow)
  end

  def depots_by_days_before
    Depot.kept.select(&:emails?).group_by(&:notify_days_before_delivery)
  end
end
