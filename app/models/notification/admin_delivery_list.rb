# frozen_string_literal: true

class Notification::AdminDeliveryList < Notification::Base
  def notify
    return unless next_delivery
    return unless Date.current == (next_delivery.date - 1.day)

    notify_admins
    notify_depots
  end

  private

  def next_delivery
    @next_delivery ||= Delivery.next
  end

  def notify_admins
    Admin.notify!(:delivery_list, delivery: next_delivery)
  end

  def notify_depots
    next_delivery.depots.select(&:emails?).each do |depot|
      DepotMailer.with(
        depot: depot,
        delivery: next_delivery
      ).delivery_list_email.deliver_later
    end
  end
end
