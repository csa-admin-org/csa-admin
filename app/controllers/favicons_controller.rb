# frozen_string_literal: true

class FaviconsController < ActionController::Base
  include ActiveStorageUrlOptions

  around_action :set_active_storage_url_options

  def show
    if Current.org.logo.attached?
      expires_in ActiveStorage.service_urls_expire_in, public: true
      redirect_to favicon_storage_url, allow_other_host: true
    else
      image = Vips::Image.new_from_file(Rails.root.join("app/assets/images/logo.png").to_s)
      data = image.resize(32.0 / image.width).pngsave_buffer
      send_data(data, type: "image/png", disposition: "inline")
    end
  end

  private

  def favicon_storage_url
    Current.org.logo.variant(resize_to_fill: [ 32, 32 ]).processed.url(disposition: :inline)
  end
end
