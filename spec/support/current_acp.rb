module CurrentACP
  extend self

  def current_acp
    ACP.find_by!(tenant_name: Apartment::Tenant.current)
  end

  def set_acp_logo(filename)
    logo = File.open(Rails.root.join("spec/fixtures/#{filename}"))
    Current.acp.logo.attach io: logo, filename: 'logo.jpg', content_type: 'image/jpg'
  end
end

RSpec.configure do |config|
  config.include(CurrentACP)
end
