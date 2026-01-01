# frozen_string_literal: true

namespace :demo do
  desc "Reset all demo tenants with fresh seed data (TENANT_NAME=demo-XY for specific tenant)"
  task reset: :environment do
    demo_tenants = Tenant.demo_tenants

    if demo_tenants.empty?
      puts "No demo tenants exist, skipping."
      exit
    end

    if ENV["TENANT_NAME"]
      tenant = ENV["TENANT_NAME"]
      unless demo_tenants.include?(tenant)
        puts "Demo tenant '#{tenant}' not found."
        exit 1
      end
      demo_tenants = [ tenant ]
    end

    demo_tenants.each do |tenant|
      puts "Resetting demo tenant '#{tenant}'..."

      Tenant.switch(tenant) do
        Demo::Seeder.new.seed!
      end

      puts "Demo tenant '#{tenant}' reset completed successfully."
    end

    puts "All demo tenants reset completed." if demo_tenants.size > 1
  end
end
