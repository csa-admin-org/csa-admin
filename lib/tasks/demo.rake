# frozen_string_literal: true

namespace :demo do
  desc "Reset all demo tenants with fresh seed data"
  task reset: :environment do
    demo_tenants = Tenant.demo_tenants

    if demo_tenants.empty?
      puts "No demo tenants exist, skipping."
      exit
    end

    demo_tenants.each do |tenant|
      puts "Resetting demo tenant '#{tenant}'..."

      Tenant.switch(tenant) do
        Demo::Seeder.new.seed!
      end

      puts "Demo tenant '#{tenant}' reset completed successfully."
    end

    puts "All demo tenants reset completed."
  end
end
