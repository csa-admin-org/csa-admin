# frozen_string_literal: true

require "tenant/migration_context"
require "tenant/schema_creator"
require "tenant/pg_adapter_patch"

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
    "public"
  end

  def switch(tenant)
    switch!(tenant)
    yield
  ensure
    reset unless Rails.env.test?
  end

  def switch!(tenant)
    return if tenant == current
    raise "Illegal tenant switch (#{current} => #{tenant})" unless outside?

    connect(tenant)
  end

  def create!(tenant)
    connection = ActiveRecord::Base.connection
    connection.execute(%(CREATE SCHEMA "#{tenant}"))
    switch!(tenant)
    SchemaCreator.new(connection, ActiveRecord::Base.connection_db_config.configuration_hash).run
  end

  def reset
    connect(nil)
  end

  private

  def connect(tenant)
    Thread.current[:current_tenant] = tenant
    Current.reset
    Sentry.set_tags(tenant: tenant)
    ActiveRecord::Base.connection.schema_search_path = schema_search_path
    ActiveRecord::Base.connection.clear_query_cache
  end

  def schema_search_path
    [ current, *persistent_schemas ].map(&:inspect).join(", ")
  end

  def persistent_schemas
    [ "extensions" ]
  end
end
