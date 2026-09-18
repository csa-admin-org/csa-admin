# frozen_string_literal: true

require "cloudflare"
require "cloudflare-rails"

namespace :hostname do
  namespace :cloudflare do
    desc "Create/check CloudFlare SSL Custom Hostnames"
    task check: :environment do
      # Suppress Ruby 4.0's experimental IO::Buffer warning from resolv.rb
      Warning[:experimental] = false

      email = ENV["CLOUDFLARE_EMAIL"]
      key = ENV["CLOUDFLARE_API_KEY"]

      Cloudflare.connect(email: email, key: key) do |cf|
        zone = cf.zones.find_by_name("csa-admin.org")

        Tenant.switch_each do |tenant|
          next if Tenant.custom? && !ENV["TENANT"]

          puts "\n#{tenant}"
          Current.org.hostnames.each do |hostname|
            print "- #{hostname} "
            custom_hostname = zone.custom_hostnames.find { |ch| ch.hostname == hostname }

            if custom_hostname
              print_custom_hostname_status(custom_hostname)
            else
              print "...creating new custom hostname\n"
              zone.custom_hostnames.create(hostname, ssl: custom_hostname_ssl)
            end
          end
        end
      end
    end

    desc "Clear CloudFlare SSL Custom Hostnames for a tenant"
    task clear: :environment do
      # Suppress Ruby 4.0's experimental IO::Buffer warning from resolv.rb
      Warning[:experimental] = false

      tenant_name = ENV["TENANT"]
      raise "TENANT environment variable is required" if tenant_name.blank?
      raise "Tenant '#{tenant_name}' does not exist" unless Tenant.exists?(tenant_name)

      email = ENV["CLOUDFLARE_EMAIL"]
      key = ENV["CLOUDFLARE_API_KEY"]

      Tenant.switch(tenant_name) do
        hostnames = Current.org.hostnames

        puts "WARNING: This will permanently delete #{hostnames.size} custom hostname(s) from Cloudflare:"
        hostnames.each { |h| puts "  - #{h}" }
        puts "\nType the tenant name '#{tenant_name}' to confirm:"
        confirmation = $stdin.gets.chomp

        unless confirmation == tenant_name
          puts "Confirmation failed. Aborting."
          exit 1
        end

        Cloudflare.connect(email: email, key: key) do |cf|
          zone = cf.zones.find_by_name("csa-admin.org")

          hostnames.each do |hostname|
            print "- #{hostname} "
            custom_hostname = zone.custom_hostnames.find { |ch| ch.hostname == hostname }

            if custom_hostname
              custom_hostname.delete
              puts "🗑️  deleted"
            else
              puts "⏭️  not found (skipped)"
            end
          end
        end

        puts "\nDone."
      end
    end

    desc "List CloudFlare SSL Custom Hostname configuration"
    task info: :environment do
      require "terminal-table"

      Warning[:experimental] = false

      email = ENV["CLOUDFLARE_EMAIL"]
      key = ENV["CLOUDFLARE_API_KEY"]

      Cloudflare.connect(email: email, key: key) do |cf|
        zone = cf.zones.find_by_name("csa-admin.org")
        custom_hostnames = zone.custom_hostnames.index_by(&:hostname)
        rows = []

        Tenant.switch_each do |tenant|
          next if Tenant.custom? && !ENV["TENANT"]

          Current.org.hostnames.each do |hostname|
            rows << custom_hostname_info_row(tenant, hostname, custom_hostnames[hostname])
          end
        end

        puts Terminal::Table.new(
          title: "Cloudflare custom hostnames",
          headings: [ "Tenant", "Hostname", "Host", "SSL", "Method", "CA", "Min TLS" ],
          rows: rows)
      end
    end

    desc "Recheck CloudFlare SSL Custom Hostnames pending validation"
    task verify: :environment do
      # Suppress Ruby 4.0's experimental IO::Buffer warning from resolv.rb
      Warning[:experimental] = false

      email = ENV["CLOUDFLARE_EMAIL"]
      key = ENV["CLOUDFLARE_API_KEY"]

      Cloudflare.connect(email: email, key: key) do |cf|
        zone = cf.zones.find_by_name("csa-admin.org")

        Tenant.switch_each do |tenant|
          next if Tenant.custom? && !ENV["TENANT"]

          puts "\n#{tenant}"
          Current.org.hostnames.each do |hostname|
            print "- #{hostname} "
            custom_hostname = zone.custom_hostnames.find { |ch| ch.hostname == hostname }

            unless custom_hostname
              puts "⏭️  not found (skipped)"
              next
            end

            if custom_hostname.ssl.pending_validation?
              print "🔄 "
              patch_custom_hostname_ssl(custom_hostname)
            end

            print_custom_hostname_status(custom_hostname)
          end
        end
      end
    end

    desc "Set CloudFlare custom hostname minimum TLS to 1.2"
    task tls: :environment do
      Warning[:experimental] = false

      email = ENV["CLOUDFLARE_EMAIL"]
      key = ENV["CLOUDFLARE_API_KEY"]

      Cloudflare.connect(email: email, key: key) do |cf|
        zone = cf.zones.find_by_name("csa-admin.org")

        Tenant.switch_each do |tenant|
          next if Tenant.custom? && !ENV["TENANT"]

          puts "\n#{tenant}"
          Current.org.hostnames.each do |hostname|
            print "- #{hostname} "
            custom_hostname = zone.custom_hostnames.find { |ch| ch.hostname == hostname }

            unless custom_hostname
              puts "⏭️  not found (skipped)"
              next
            end

            unless patch_min_tls?(custom_hostname)
              puts "⏭️  #{tls_skip_reason(custom_hostname)}"
              next
            end

            patch_custom_hostname_ssl(custom_hostname)
            puts "🔧 #{custom_hostname.ssl.settings.min_tls_version}"
          end
        end
      end
    end
  end

  # Backward compatibility alias: hostname:cloudflare → hostname:cloudflare:check
  desc "Create/check CloudFlare SSL Custom Hostnames (alias for hostname:cloudflare:check)"
  task cloudflare: "hostname:cloudflare:check"

  desc "Check DNS records for all tenants"
  task dns: :environment do
    include CloudflareRails::CheckTrustedProxies

    invalid_tenants = []

    Resolv::DNS.open do |dns|
      Tenant.switch_each do |tenant|
        next if Tenant.custom? && !ENV["TENANT"]

        puts "\n#{tenant}"

        ns = dns.getresources Current.org.domain, Resolv::DNS::Resource::IN::NS
        puts "- NS: #{ns.map(&:name).join(", ")}"

        Current.org.hostnames.each do |hostname|
          print "- #{hostname} "

          ip4 = dns.getresources hostname, Resolv::DNS::Resource::IN::A
          check4 = ip4.present? && ip4.all? { |ip| cloudflare_ip?(ip.address.to_s) }
          ip6 = dns.getresources hostname, Resolv::DNS::Resource::IN::AAAA
          check6 = ip6.present? && ip6.all? { |ip| cloudflare_ip?(ip.address.to_s) }
          valid = check4 && check6

          invalid_tenants << tenant unless valid

          print valid ? " ✅\n" : " ❌\n"
        end
      end
    end

    invalid_tenants.uniq!
    if invalid_tenants.present?
      puts "\nInvalid tenants (#{invalid_tenants.count}):"
      puts invalid_tenants.join(",")
    end
  end
end

def custom_hostname_ssl
  {
    method: "txt",
    type: "dv",
    settings: { min_tls_version: "1.2" }
  }
end

def custom_hostname_info_row(tenant, hostname, custom_hostname)
  unless custom_hostname
    return [ tenant, hostname, "missing", "-", "-", "-", "-" ]
  end

  ssl = custom_hostname.ssl
  [
    tenant,
    hostname,
    custom_hostname.result[:status],
    ssl.status,
    ssl.method,
    ssl.to_h[:certificate_authority] || "default",
    ssl.settings.min_tls_version || "1.0 (default)"
  ]
end

def min_tls_1_2?(custom_hostname)
  custom_hostname.ssl.settings.min_tls_version == "1.2"
end

def patch_min_tls?(custom_hostname)
  custom_hostname.ssl.active? && !min_tls_1_2?(custom_hostname)
end

def tls_skip_reason(custom_hostname)
  if min_tls_1_2?(custom_hostname)
    "already 1.2"
  else
    "SSL #{custom_hostname.ssl.status}"
  end
end

def patch_custom_hostname_ssl(custom_hostname)
  custom_hostname.update_settings(ssl: {
    method: custom_hostname.ssl.method,
    type: custom_hostname.ssl.type || "dv",
    settings: { min_tls_version: "1.2" }
  })
end

def print_custom_hostname_status(custom_hostname)
  status = custom_hostname.result[:status]
  if status == "active" && custom_hostname.ssl.active? && min_tls_1_2?(custom_hostname)
    print " ✅\n"
  else
    print " ❌\n"
    puts "  - Hostname Status: #{custom_hostname.result[:status]}"
    puts "  - SSL Status:      #{custom_hostname.ssl.status}"
    unless min_tls_1_2?(custom_hostname)
      puts "  - Min TLS:         #{custom_hostname.ssl.settings.min_tls_version || "1.0 (default)"}"
    end
    if custom_hostname.ssl.pending_validation?
      print_ssl_txt_records(custom_hostname.ssl.to_h)
    end
    if custom_hostname.ssl.validation_errors
      puts "  Validation Errors:"
      custom_hostname.ssl.validation_errors.each do |error|
        puts "    - #{error[:message]}"
      end
    end
  end
end

def print_ssl_txt_records(ssl)
  ssl ||= {}
  records = Array(ssl[:validation_records])
  records = [ ssl ] if records.empty? && ssl[:txt_name]

  if records.none? { |record| record[:txt_name] }
    puts "    TXT records not yet available"
    return
  end

  records.group_by { |record| record[:txt_name] }.each do |txt_name, group|
    next unless txt_name

    puts "    TXT NAME:  #{txt_name.delete_suffix(".#{Current.org.domain}")}"
    group.each do |record|
      puts "    TXT VALUE: #{record[:txt_value]}"
    end
  end
end
