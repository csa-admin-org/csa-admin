# frozen_string_literal: true

module CurrentOrg
  extend self

  def current_org
    Organization.find_by!(tenant_name: Tenant.current)
  end
end

RSpec.configure do |config|
  config.include(CurrentOrg)
end
