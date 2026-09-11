# frozen_string_literal: true

namespace :organizations do
  desc "List organizations by when their next fiscal year starts"
  task next_fiscal_year: :environment do
    groups = Hash.new { |h, k| h[k] = [] }

    Tenant.switch_each do
      org = Organization.first
      next unless org

      groups[org.next_fiscal_year.range.min] << org.name
    end

    groups.sort.each do |date, names|
      puts "-- #{date} --"
      names.each { |name| puts "  #{name}" }
    end
  end

  desc "Encrypt plaintext api_token and icalendar_auth_token (CONFIRM=true; optional TENANT=slug)"
  task encrypt_tokens: :environment do
    abort "CONFIRM=true required" unless ENV["CONFIRM"].in?(%w[1 true yes])

    Tenant.switch_each do |tenant|
      next if Tenant.custom? && ENV["TENANT"].blank?

      org = Organization.first
      next unless org

      pending = %i[api_token icalendar_auth_token].select { |attr|
        org.public_send(attr).present? && !org.encrypted_attribute?(attr)
      }
      if pending.empty?
        puts "#{tenant}: already encrypted"
        next
      end

      org.encrypt
      puts "#{tenant}: encrypted #{pending.join(", ")}"
    end
  end
end
