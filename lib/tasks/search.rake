# frozen_string_literal: true

namespace :search do
  desc "Reindex search entries for all tenants (or TENANT=name for a specific one)"
  task reindex: :environment do
    Tenant.switch_each do |tenant|
      print "Reindexing #{tenant}... "
      count = SearchEntry.rebuild!
      puts "#{count} entries indexed."
    rescue => e
      puts "ERROR: #{e.message}"
    end
  end
end
