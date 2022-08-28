module Tenant
  module MigrationContext
    def migrate(target_version = nil, &block)
      puts "Migrating #{Tenant.default}"
      super
      switch_each do |tenant|
        puts "Migrating #{tenant}"
        super
      end
    end

    def rollback(steps = 1)
      puts "Rolling back #{Tenant.default}"
      super
      switch_each do |tenant|
        puts "Rolling back #{tenant}"
        super
      end
    end

    def run(direction, target_version)
      puts "#{direction} #{Tenant.default}"
      super
      switch_each do |tenant|
        puts "#{direction} #{tenant}"
        super
      end
    end

    private

    def switch_each
      tenants = ACP.pluck(:tenant_name)
      tenants.each do |tenant|
        Tenant.switch(tenant) { yield tenant }
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::MigrationContext.prepend(Tenant::MigrationContext)
end
