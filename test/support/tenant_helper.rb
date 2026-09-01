# frozen_string_literal: true

module TenantHelper
  def with_tenant(tenant_name)
    original_tenant = Thread.current[:current_tenant]
    Thread.current[:current_tenant] = tenant_name
    yield
  ensure
    Thread.current[:current_tenant] = original_tenant
  end

  # Real shard switch. `with_tenant` only pokes the thread-local name.
  # Nested `Tenant.switch` is illegal, so this disconnects first.
  def with_connected_tenant(tenant_name)
    previous = Tenant.current
    Tenant.disconnect
    Tenant.connect(tenant_name)
    yield
  ensure
    Tenant.disconnect
    Tenant.connect(previous) if previous
  end

  def with_demo_tenant
    Thread.current[:_demo_mode] = true
    yield
  ensure
    Thread.current[:_demo_mode] = false
  end
end
