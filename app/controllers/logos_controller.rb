class LogosController < ActionController::Base
  around_action :switch_tenant!

  def show
    if Current.org.logo.attached?
      expires_in 1.day, public: true
      logo = Current.org.logo
      send_data(logo.download,
        filename: logo.filename.to_s,
        type: logo.content_type,
        disposition: 'inline')
    else
      File.open(Rails.root.join("app/assets/images/logo.png"), "r") do |f|
        send_data(f.read, type: "image/png", disposition: "inline")
      end
    end
  end

  private

  def switch_tenant!
    tenant_name = params[:id]
    if Organization.exists?(tenant_name: params[:id])
      Tenant.switch(tenant_name) { yield }
    else
      head :not_found
    end
  end
end
