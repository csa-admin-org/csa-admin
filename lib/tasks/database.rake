# frozen_string_literal: true

namespace :db do
  namespace :schema do
    # Override db:schema:load to load schema into all tenant shards.
    # Rails' default db:schema:load doesn't handle shards, only named databases.
    task load: :environment do
      schema_file = Rails.root.join("db/schema.rb")

      # Ensure shard connections are established (loads ApplicationRecord)
      Rails.application.eager_load!

      Tenant.all.each do |tenant|
        puts "Loading schema into #{tenant}..."
        Tenant.switch(tenant) do
          ActiveRecord::Tasks::DatabaseTasks.load_schema(
            ActiveRecord::Base.connection_db_config,
            :ruby,
            schema_file
          )
        end
      end
    end
  end

  namespace :rollback do
    desc "Rollback all tenants database to a specific VERSION"
    task all: :environment do
      version = ENV["VERSION"]
      raise "VERSION is required" unless version

      class ActiveRecord::Base
        connects_to shards: Tenant.all.map(&:to_sym).map { |tenant|
          [ tenant, writing: tenant ]
        }.to_h
      end

      migrations_paths = ActiveRecord::Migrator.migrations_paths
      Tenant.switch_each do |tenant|
        migration_context = ActiveRecord::MigrationContext.new(migrations_paths)
        migration_context.migrate(version.to_i)
      end
    end
  end
end
