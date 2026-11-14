# frozen_string_literal: true

require "public_suffix"

module Tenant
  extend self

  def all
    if ENV["TENANT"]
      ENV["TENANT"].split(",")
    else
      @all ||= config.keys.map(&:to_s)
    end
  end

  def all_with_aliases
    config.keys.map(&:to_s) + config.flat_map { |k, v| v["aliases"] }.compact
  end

  def find_by(host:)
    @hosts ||= config.flat_map { |tenant, attrs|
      [
        [ relevant_host(attrs["admin_host"]), tenant.to_s ],
        [ relevant_host(attrs["members_host"]), tenant.to_s ]
      ]
    }.reject { |host_key, _| host_key.nil? }.to_h

    host_key = relevant_host(host)
    @hosts[host_key] if host_key
  end

  def admin_host
    config.dig(current.to_s, "admin_host")
  end

  def members_host
    config.dig(current.to_s, "members_host")
  end

  def domain
    PublicSuffix.parse(admin_host).domain
  end

  def hostnames
    [ admin_host, members_host ]
  end

  # Yields each tenant with `current` set, without opening the tenant DB.
  # Prefer this over `switch_each` for config-only walks (hosts, DNS, …).
  def config_each(tenants = all)
    Array(tenants).each do |tenant|
      enter(tenant)
      begin
        yield tenant
      ensure
        leave
      end
    end
    nil
  end

  def local_url(host, port: nil)
    options = local_url_options(host, port: port)
    url = "#{options[:protocol]}://#{options[:host]}"
    url += ":#{options[:port]}" if options[:port]
    url
  end

  def local_url_options(host, port: nil)
    return { protocol: "https", host: host } unless Rails.env.development?

    parsed = PublicSuffix.parse(host)
    labels = [ parsed.trd, parsed.sld ].compact.join(".")

    if ENV["DEV_ORIGIN"] == "localhost"
      { protocol: "http", host: "#{labels}.localhost", port: port || ENV.fetch("PORT", "3000") }
    else
      { protocol: "https", host: "#{labels}.test" }
    end
  end

  # Config-only rows for the Mission Control launcher (no tenant DB).
  # Pass +port+ from the request so cloud-agent port forwards match the current URL.
  def launcher_tenants(port: nil)
    all.sort.map { |name| launcher_tenant(name, port: port) }
  end

  def launcher_tenant(name, port: nil)
    attrs = config.fetch(name.to_s)
    {
      name: name.to_s,
      state: attrs["state"] || "production",
      aliases: Array(attrs["aliases"]),
      admin_host: attrs["admin_host"],
      members_host: attrs["members_host"],
      admin_url: local_url(attrs["admin_host"], port: port),
      members_url: local_url(attrs["members_host"], port: port),
      logo_url: "https://cdn.csa-admin.org/logos/#{name}"
    }
  end

  def state
    config.dig(current.to_s, "state") || "production"
  end

  def custom?
    state == "custom"
  end

  DEMO_TENANT_PATTERN = /\Ademo-([a-z]{2})\z/

  def demo?
    Thread.current[:_demo_mode] || DEMO_TENANT_PATTERN.match?(current)
  end

  def demo_tenants
    all.grep(DEMO_TENANT_PATTERN)
  end

  # Reads config, not all, so ENV["TENANT"] does not hide the other demos.
  def demo_admin_hosts
    {
      "en" => config.dig("demo-en", "admin_host"),
      "fr" => config.dig("demo-fr", "admin_host"),
      "de" => config.dig("demo-de", "admin_host")
    }.compact
  end

  def demo_language
    if Thread.current[:_demo_mode]
      Current.org.languages.first
    else
      current&.match(DEMO_TENANT_PATTERN)&.[](1)
    end
  end

  def find_with_aliases(tenant)
    mapping = {}
    config.each { |k, v|
      mapping[k.to_s] = k
      Array(v["aliases"]).each { |a| mapping[a] = k }
    }
    mapping[tenant.to_s]
  end

  def exists?(tenant)
    all.include?(tenant)
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

  def switch_each(tenants = all)
    Array(tenants).each do |tenant|
      begin
        switch(tenant) { yield(tenant) }
      ensure
        # switch skips leave in test so inline jobs keep the current tenant.
        # Sequential walks would then nested-switch. Reset between tenants.
        leave if Rails.env.test?
      end
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
    Rails.error.set_context(tenant: tenant)
    Rails.event.set_context(tenant: tenant)
  end

  def leave
    self.current = nil
    Rails.event.clear_context
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

  def relevant_host(host)
    host = PublicSuffix.parse(host)
    # Ignore tld locally
    Rails.env.local? ? host.sld : host.to_s
  rescue PublicSuffix::Error
    host if Rails.env.local?
  end

  def ensure_test_env_or_rails_console!
    return if Rails.env.test?
    return if defined?(Rails::Console)

    raise "Only for use in Rails console or test environment"
  end
end
