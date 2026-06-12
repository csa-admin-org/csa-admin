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
        block_automated_browsers: true,
        cors_origins: cors_origins)

      Current.org.update!(
        cap_site_key: result.fetch("siteKey"),
        cap_secret_key: result.fetch("secretKey"))

      puts "✅ #{tenant}: #{result.fetch('siteKey')}"
      puts "   CORS: #{cors_origins.join(', ')}"
    end
  end

  namespace :development do
    desc "Create or update one allow-all Cap site key for local development"
    task setup: :environment do
      raise "Only run this task in development" unless Rails.env.development?

      client = Cap::Client.new
      if ENV["CAP_DEVELOPMENT_SITE_KEY"].present?
        client.update_key_config(
          site_key: ENV.fetch("CAP_DEVELOPMENT_SITE_KEY"),
          instrumentation: true,
          block_automated_browsers: true,
          cors_origins: [])

        puts "Updated CAP_DEVELOPMENT_SITE_KEY CORS config for local development."
      else
        result = client.create_key(
          name: "CSA Admin [development]",
          instrumentation: true,
          block_automated_browsers: true,
          cors_origins: [])

        puts "Add these lines to .env.development.local:"
        puts "CAP_DEVELOPMENT_SITE_KEY=#{result.fetch('siteKey')}"
        puts "CAP_DEVELOPMENT_SECRET_KEY=#{result.fetch('secretKey')}"
      end
    end
  end
end
