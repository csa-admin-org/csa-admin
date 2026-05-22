# frozen_string_literal: true

class Liquid::AdminDeliveryDrop < Liquid::DeliveryDrop
  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .delivery_url(@delivery.id, host: Current.org.admin_url)
  end
end
