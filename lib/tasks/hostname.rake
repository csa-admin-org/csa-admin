# frozen_string_literal: true

require "cloudflare"
require "cloudflare-rails"

namespace :hostname do
  desc "Create/check CloudFlare SSL Custom Hostnames"
  task cloudflare: :environment do
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
            status = custom_hostname.result[:status]
            if status == "active" && custom_hostname.ssl.active?
              print " ✅\n"
            else
              print " ❌\n"
              puts "  - Hostname Status: #{custom_hostname.result[:status]}"
              puts "  - SSL Status:      #{custom_hostname.ssl.status}"
              if custom_hostname.ssl.pending_validation?
                puts "    TXT NAME:  #{custom_hostname.ssl.to_h[:txt_name].gsub(".#{Current.org.domain}", "")}"
                puts "    TXT VALUE: #{custom_hostname.ssl.to_h[:txt_value]}"
              end
              if custom_hostname.ssl.validation_errors
                puts "  Validation Errors:"
                custom_hostname.ssl.validation_errors.each do |error|
                  puts "    - #{error[:message]}"
                end
              end
            end
          else
            print "...creating new custom hostname\n"
            zone.custom_hostnames.create(hostname,
              ssl: { method: "txt" },
              settings: { min_tls_version: "1.2" })
          end
        end
      end
    end
  end

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
