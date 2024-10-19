# frozen_string_literal: true

class Liquid::AdminDeliveryDrop < Liquid::Drop
  def initialize(delivery)
    @delivery = delivery
  end

  def date
    I18n.l(@delivery.date)
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .delivery_url(@delivery.id, {}, host: Current.org.admin_url)
  end
end
