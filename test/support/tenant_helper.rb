# frozen_string_literal: true

module TenantHelper
  def with_tenant(tenant_name)
    original_tenant = Thread.current[:current_tenant]
    Thread.current[:current_tenant] = tenant_name
    yield
  ensure
    Thread.current[:current_tenant] = original_tenant
  end

  def with_demo_tenant
    Thread.current[:_demo_mode] = true
    yield
  ensure
    Thread.current[:_demo_mode] = false
  end
end
