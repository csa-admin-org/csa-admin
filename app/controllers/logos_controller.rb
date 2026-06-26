# frozen_string_literal: true

class LogosController < ActionController::Base
  include ActiveStorageUrlOptions

  around_action :switch_tenant
  around_action :set_active_storage_url_options

  def show
    if Current.org.logo.attached?
      expires_in ActiveStorage.service_urls_expire_in, public: true
      redirect_to Current.org.logo.url(disposition: :inline), allow_other_host: true
    else
      File.open(Rails.root.join("app/assets/images/logo.png"), "rb") do |f|
        send_data(f.read, type: "image/png", disposition: "inline")
      end
    end
  end

  private

  def switch_tenant
    tenant = params[:id]
    if Tenant.exists?(tenant)
      Tenant.switch(tenant) { yield }
    else
      head :not_found
    end
  end
end
