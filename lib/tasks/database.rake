# frozen_string_literal: true

namespace :db do
  namespace :rollback do
    desc "Rollback all tenants database to a specific VERSION"
    task all: :environment do
      version = ENV["VERSION"]
      raise "VERSION is required" unless version

      migrations_paths = ActiveRecord::Migrator.migrations_paths
      Tenant.switch_each do |tenant|
        migration_context = ActiveRecord::MigrationContext.new(migrations_paths)
        migration_context.migrate(version.to_i)
      end
    end
  end
end
