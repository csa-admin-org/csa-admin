# frozen_string_literal: true

class FaviconsController < ActionController::Base
  include ActiveStorageUrlOptions

  around_action :set_active_storage_url_options

  def show
    if Current.org.logo.attached?
      cache_active_storage_redirect
      redirect_to favicon_storage_url, allow_other_host: true
    else
      send_file(
        Rails.root.join("app/assets/images/favicon.png"),
        type: "image/png",
        disposition: "inline")
    end
  end

  private

  def favicon_storage_url
    Current.org.logo.variant(resize_to_fill: [ 32, 32 ]).processed.url(disposition: :inline)
  end
end
