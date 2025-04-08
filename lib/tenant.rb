# frozen_string_literal: true

module Tenant
  extend self

  def all
    if ENV["TENANT"]
      ENV["TENANT"].split(",")
    else
      @all ||= config.keys.map(&:to_s)
    end
  end

  def numbered
    config.group_by { |tenant, attrs| attrs["state"] }.flat_map { |state, tenants|
      offset =
        case state
        when "onboarding" then 99
        when "custom" then 199
        else 0
        end
      tenants.map.with_index { |(tenant, attrs), i| [ i + 1 + offset, tenant ] }
    }.to_h
  end

  def find_by(host:)
    @domains ||= config.map { |tenant, attrs|
      [ relevant_domain(attrs["domain"]), tenant.to_s ]
    }.to_h
    @domains[relevant_domain(host)]
  end

  def domain
    config.dig(current.to_s, "domain")
  end

  def state
    config.dig(current.to_s, "state") || "production"
  end

  def custom?
    state == "custom"
  end

  def exists?(tenant)
    all.include?(tenant.to_s)
  end

  def current
    Thread.current[:current_tenant]
  end

  def outside?
    !current
  end

  def inside?
    !outside?
  end

  def switch_each
    all.each do |tenant|
      switch(tenant) { yield(tenant) }
    end
    nil
  end

  def switch(tenant)
    enter(tenant)
    ActiveRecord::Base.connected_to(shard: tenant.to_sym) do
      ActiveRecord::Base.prohibit_shard_swapping(!Rails.env.test?) do
        yield
      end
    end
  ensure
    # In test environment, where jobs are run inline, we don't want to reset
    # the current tenant as will break tests that rely on it.
    leave unless Rails.env.test?
  end

  def connect(tenant)
    ensure_test_env_or_rails_console!

    enter(tenant)
    ActiveRecord::Base.connecting_to(shard: tenant.to_sym)
  end

  # Only for use in console
  def disconnect
    ensure_test_env_or_rails_console!

    leave
    ActiveRecord::Base.connecting_to(shard: :default)
  end

  private

  def enter(tenant)
    raise "Unknown tenant '#{tenant}'" unless exists?(tenant)
    return if tenant == current
    raise "Illegal tenant switch (#{current} => #{tenant})" unless outside?

    self.current = tenant
    Appsignal.add_tags(tenant: tenant)
  end

  def leave
    self.current = nil
  end

  def current=(tenant)
    Thread.current[:current_tenant] = tenant
    Current.reset
  end

  def config
    @config ||= begin
      config_file = Rails.root.join("config", "tenant.yml")
      YAML.load_file(config_file, aliases: true)[Rails.env]
    end
  end

  def relevant_domain(domain)
    domain = PublicSuffix.parse(domain)
    # Ignore tld locally
    Rails.env.local? ? domain.sld : domain.domain
  end

  def ensure_test_env_or_rails_console!
    return if Rails.env.test?
    return if defined?(Rails::Console)

    raise "Only for use in Rails console or test environment"
  end
end
