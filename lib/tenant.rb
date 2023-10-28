require 'tenant/migration_context'
require 'tenant/schema_creator'
require 'tenant/pg_adapter_patch'
require 'tenant/active_record_signed_id_acp'

module Tenant
  extend self

  def current
    Thread.current[:current_tenant] ||= default
  end

  def outside?
    current == default
  end

  def inside?
    !outside?
  end

  def default
    'public'
  end

  def switch(tenant)
    previous_tenant = current
    switch!(tenant)
    yield
  ensure
    switch!(previous_tenant) rescue reset
  end

  def switch!(tenant = nil)
    return reset if tenant.nil?

    unless to_or_from_public?(tenant.to_s)
      Sentry.capture_message('Illegal tenant switch', extra: {
        current: current,
        target: tenant,
        search_path: ActiveRecord::Base.connection.schema_search_path.inspect
      })
    end

    connect(tenant)
    ActiveRecord::Base.connection.clear_query_cache
  end

  def connect(tenant = nil)
    return reset if tenant.nil?

    Thread.current[:current_tenant] = tenant.to_s
    Current.reset
    Sentry.set_tags(tenant: tenant)
    ActiveRecord::Base.connection.schema_search_path = full_search_path
  end

  def reset
    Thread.current[:current_tenant] = nil
    Current.reset
    Sentry.set_tags(tenant: nil)
    ActiveRecord::Base.connection.schema_search_path = full_search_path
  end

  def create!(tenant)
    connection = ActiveRecord::Base.connection
    connection.execute(%(CREATE SCHEMA "#{tenant}"))
    switch!(tenant)
    SchemaCreator.new(connection, ActiveRecord::Base.connection_db_config.configuration_hash).run
  end

  private

  def to_or_from_public?(tenant)
    !tenant || tenant == default || outside?
  end

  def neutral_search_path
    [default_tenant, *persistent_schemas].map(&:inspect).join(', ')
  end

  def full_search_path
    [current, *persistent_schemas].map(&:inspect).join(', ')
  end

  def persistent_schemas
    ['extensions']
  end
end
