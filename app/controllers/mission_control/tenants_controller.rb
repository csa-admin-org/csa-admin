# frozen_string_literal: true

class MissionControl::TenantsController < MissionControl::BaseController
  def index
    @tenants = Tenant.launcher_tenants
  end
end
