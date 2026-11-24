# frozen_string_literal: true

namespace :cap do
  desc "Create Cap site key for tenant(s)"
  task setup: :environment do
    client = Cap::Client.new
    tenant_config = YAML
      .load_file(Rails.root.join("config/tenant.yml"), aliases: true)
      .fetch(Rails.env)

    Tenant.switch_each do |tenant|
      next if Tenant.custom? && !ENV["TENANT"]
      if Current.org.cap_site_key? && !ENV["FORCE"]
        puts "⏭️  #{tenant} already has a Cap key; use FORCE=1 to replace it"
        next
      end

      cors_origins = tenant_config
        .fetch(tenant)
        .values_at("admin_host", "members_host")
        .compact
        .map { |host| "https://#{host}" }
      result = client.create_key(
        name: tenant,
        instrumentation: true,
        block_automated_browsers: false,
        cors_origins: cors_origins)

      Current.org.update!(
        cap_site_key: result.fetch("siteKey"),
        cap_secret_key: result.fetch("secretKey"))

      puts "✅ #{tenant}: #{result.fetch('siteKey')}"
      puts "   CORS: #{cors_origins.join(', ')}"
    end
  end

  desc "Rotate v3 Cap secrets that capd 4 rejects. Dry-run unless CONFIRM=1"
  task rotate_secrets: :environment do
    client = Cap::Client.new
    confirm = ENV["CONFIRM"] == "1"
    keys = client.keys.index_by { |key| key.fetch("siteKey") }
    seen = []

    Tenant.switch_each do |tenant|
      next if Tenant.custom? && !ENV["TENANT"]

      site_key = Current.org.cap_site_key
      if site_key.blank?
        puts "Org row with no site key: #{tenant}"
        next
      end

      seen << site_key
      key = keys[site_key]
      unless key
        puts "Org site key missing from Cap: #{tenant} #{site_key}"
        next
      end
      next unless key["secretOutdated"]

      puts "#{confirm ? '✅' : 'dry-run'} #{tenant}: rotate #{site_key}"
      next unless confirm

      result = client.rotate_secret(site_key)
      secret = result.fetch("secretKey")
      begin
        Current.org.update!(cap_secret_key: secret)
      rescue StandardError => error
        warn "#{tenant} #{site_key}: rotated on Cap but not saved (#{error.class}). Save this secret, then re-run. A second rotate replaces it."
        warn secret
        abort
      end
    end

    keys.each_value do |key|
      next unless key["secretOutdated"]
      next if seen.include?(key.fetch("siteKey"))

      puts "Cap key missing from this walk, secretOutdated: #{key['name']} #{key.fetch('siteKey')}"
    end
    puts "Re-run with CONFIRM=1 to rotate." unless confirm
  end

  desc "Pin every Cap key to sha256-pow. Dry-run unless CONFIRM=1"
  task pin_sha256: :environment do
    client = Cap::Client.new
    confirm = ENV["CONFIRM"] == "1"
    details = client.keys.map { |key| client.key(key.fetch("siteKey")) }
    blocked = details.select { |detail|
      config = detail.dig("key", "config")
      next false unless config.is_a?(Hash)

      protocol = config["protocol"]
      protocol.present? && protocol != "sha256-pow"
    }
    if blocked.any?
      blocked.each do |detail|
        key = detail.fetch("key")
        puts "#{key['name']} #{key.fetch('siteKey')}: #{key.dig('config', 'protocol')}"
      end
      abort "Refusing to pin: a key is not sha256-pow. Nothing was written."
    end

    pending = details.reject { |detail|
      detail.dig("key", "config", "protocol") == "sha256-pow"
    }
    pending.each do |detail|
      key = detail.fetch("key")
      puts "#{confirm ? '✅' : 'dry-run'} pin #{key['name']} #{key.fetch('siteKey')}"
      client.pin_sha256(key.fetch("siteKey")) if confirm
    end
    puts "Already sha256-pow: #{details.size - pending.size}"
    puts "Re-run with CONFIRM=1 to pin." unless confirm
  end

  namespace :development do
    desc "Create or update one allow-all Cap site key for local development"
    task setup: :environment do
      raise "Only run this task in development" unless Rails.env.development?

      client = Cap::Client.new
      if Rails.app.creds.option(:cap_development_site_key).present?
        client.update_key_config(
          site_key: Rails.app.creds.require(:cap_development_site_key),
          instrumentation: true,
          block_automated_browsers: false,
          cors_origins: [])

        puts "Updated CAP_DEVELOPMENT_SITE_KEY CORS config for local development."
      else
        result = client.create_key(
          name: "CSA Admin [development]",
          instrumentation: true,
          block_automated_browsers: false,
          cors_origins: [])

        puts "Add these lines to .env:"
        puts "CAP_DEVELOPMENT_SITE_KEY=#{result.fetch('siteKey')}"
        puts "CAP_DEVELOPMENT_SECRET_KEY=#{result.fetch('secretKey')}"
      end
    end
  end
end
