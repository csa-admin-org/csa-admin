# frozen_string_literal: true

class FaviconsController < ActionController::Base
  def show
    if Current.org.logo.attached?
      expires_in 1.day, public: true
      variant = Current.org.logo.variant(resize_to_fill: [ 32, 32 ]).processed
      send_data(variant.service.download(variant.key),
        type: Current.org.logo.content_type,
        disposition: "inline")
    else
      image = Vips::Image.new_from_file(Rails.root.join("app/assets/images/logo.png").to_s)
      data = image.resize(32.0 / image.width).pngsave_buffer
      send_data(data, type: "image/png", disposition: "inline")
    end
  end
end
