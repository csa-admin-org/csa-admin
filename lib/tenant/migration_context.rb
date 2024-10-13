# frozen_string_literal: true

module Tenant
  module MigrationContext
    def migrate(target_version = nil, &block)
      if primary?
        puts "Migrating #{Tenant.default}"
        super
        switch_each do |tenant|
          puts "Migrating #{tenant}"
          super
        end
      else
        super
      end
    end

    def rollback(steps = 1)
      if primary?
        puts "Rolling back #{Tenant.default}"
        super
        switch_each do |tenant|
          puts "Rolling back #{tenant}"
          super
        end
      else
        super
      end
    end

    def run(direction, target_version)
      if primary?
        puts "#{direction} #{Tenant.default}"
        super
        switch_each do |tenant|
          puts "#{direction} #{tenant}"
          super
        end
      else
        super
      end
    end

    private

    def switch_each
      tenants = Organization.pluck(:tenant_name)
      tenants.each do |tenant|
        Tenant.switch(tenant) { yield tenant }
      end
    end

    def primary?
      Array(@migrations_paths).all? { |path| path.end_with?("db/migrate") }
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::MigrationContext.prepend(Tenant::MigrationContext)
end
