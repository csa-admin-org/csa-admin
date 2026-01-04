# frozen_string_literal: true

class Notification::AdminDeliveryList < Notification::Base
  def notify
    return unless next_delivery
    return unless Date.current == (next_delivery.date - 1.day)

    notify_depots
    notify_admins
  end

  private

  def next_delivery
    @next_delivery ||= Delivery.next
  end

  def notify_depots
    next_delivery.depots.select(&:emails?).each do |depot|
      AdminMailer.with(
        depot: depot,
        delivery: next_delivery
      ).depot_delivery_list_email.deliver_later
    end
  end

  def notify_admins
    Admin.notify!(:delivery_list, delivery: next_delivery)
  end
end
