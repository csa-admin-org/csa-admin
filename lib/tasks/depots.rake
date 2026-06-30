# frozen_string_literal: true

namespace :depots do
  desc "Geocode kept depots with complete addresses and missing coordinates (TENANT=slug optional)"
  task geocode_missing: :environment do
    unless Geocoding.enabled?
      puts "Geocoding is disabled. Set GEOCODING_ENABLED=1 to run this task."
      next
    end

    totals = Hash.new(0)

    Tenant.switch_each do |tenant|
      counts = Hash.new(0)

      depots = Depot.kept.select(&:geocodable_address?).select(&:coordinates_missing?)

      depots.each do |depot|
        counts[:processed] += 1

        if depot.geocode
          counts[:updated] += 1
        else
          counts[:failed] += 1
        end
      end

      puts "#{tenant}: processed=#{counts[:processed]} updated=#{counts[:updated]} failed=#{counts[:failed]}"
      counts.each { |key, value| totals[key] += value }
    end

    puts "Total: processed=#{totals[:processed]} updated=#{totals[:updated]} failed=#{totals[:failed]}"
  end
end
