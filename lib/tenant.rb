# frozen_string_literal: true

require "tenant/migration_context"
require "tenant/schema_creator"
require "tenant/pg_adapter_patch"

module Tenant
  extend self

  def all
    @all ||= organization_credentials.keys.map(&:to_s)
  end

  def find_by(host:)
    @domains ||= organization_credentials.map { |tenant, attrs|
      [ relevant_domain(attrs[:domain]), tenant.to_s ]
    }.to_h
    @domains[relevant_domain(host)]
  end

  def all_schemas
    ActiveRecord::Base.connection.execute("SELECT schema_name FROM information_schema.schemata").map { |row| row["schema_name"] }
  end

  def schema_exists?(tenant)
    ActiveRecord::Base.connection.schema_exists?(tenant)
  end

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

  def switch_each
    (all & all_schemas).each do |tenant|
      switch(tenant) { yield(tenant) }
    end
    nil
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

    yield # Create organization here
    raise "Organization not created" unless Organization.exists?

    Permission.create_superadmin!
    MailTemplate.create_all!
    Newsletter::Template.create_defaults!
    DeliveryCycle.create_default!
  end

  def reset
    connect(nil)
  end

  private

  def organization_credentials
    Rails.application.credentials.dig(:organizations)
  end

  def relevant_domain(domain)
    domain =  PublicSuffix.parse(domain)
    # Ignore tld locally
    Rails.env.local? ? domain.sld : domain.domain
  end

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
