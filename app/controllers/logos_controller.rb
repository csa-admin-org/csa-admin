# frozen_string_literal: true

class LogosController < ActionController::Base
  include ActiveStorageUrlOptions

  around_action :switch_tenant
  around_action :set_active_storage_url_options

  def show
    if Current.org.logo.attached?
      cache_active_storage_redirect
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

  # The app host has no tenant. A disk URL on that host cannot build a path.
  # Point it at the tenant admin host, which the middleware can enter.
  # Local lookup ignores the TLD, so csa-admin.test matches demo-en and must
  # not count as this tenant's host.
  def active_storage_url_options
    return super if Tenant.find_by(host: request.host) == Tenant.current

    local = Tenant.local_url_options(Tenant.admin_host)
    {
      protocol: "#{local[:protocol]}://",
      host: local[:host],
      port: local[:port]
    }.compact
  end
end
