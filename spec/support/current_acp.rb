module CurrentACP
  extend self

  def current_acp
    ACP.find_by!(tenant_name: Apartment::Tenant.current)
  end
end

RSpec.configure do |config|
  config.include(CurrentACP)
end
