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
end
