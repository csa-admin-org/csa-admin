# frozen_string_literal: true

def for_each_tenant
  Tenant.all.each do |tenant|
    puts "#{tenant}..."
    ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: tenant) do |pool|
      yield tenant, pool
    end
  end
end

# Non-first tenants set `schema_dump: false`, so Rails' migrate_all opens an
# empty SQLite without loading schema.rb. Replaying post-squash migrations then
# fails. Empty means missing file or only system tables — a half-migrated leftover
# already has application tables and is left alone.
def uninitialized_tenant_database?(pool)
  system_tables = %w[ar_internal_metadata schema_migrations]

  pool.with_connection do |connection|
    (connection.tables - system_tables).empty?
  end
rescue ActiveRecord::NoDatabaseError
  true
end

# except_schema_dump: db:prepare already schema-loads shards whose schema_dump
# is set (the first development tenant, and every test tenant). Preloading
# those makes initialize_database skip them and then skip seeds. db:migrate
# passes false and loads every empty shard, including the dump shard.
def ensure_tenant_databases_initialized(except_schema_dump: false)
  schema_file = Rails.root.join("db/schema.rb").to_s

  Tenant.all.each do |tenant|
    ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: tenant) do |pool|
      next if except_schema_dump && pool.db_config.schema_dump
      next unless uninitialized_tenant_database?(pool)

      puts "Loading schema for new tenant #{tenant}..."
      ActiveRecord::Tasks::DatabaseTasks.load_schema(pool.db_config, :ruby, schema_file)
    end
  end
end

namespace :db do
  namespace :schema do
    # Override db:schema:load to load schema into all tenant shards.
    # Rails' default db:schema:load doesn't handle shards, only named databases.
    Rake::Task["db:schema:load"].clear

    task load: [ :load_config, :check_protected_environments ] do
      # Disconnect all connections to ensure fresh connections after db:drop/db:create.
      # Without this, SQLite connections may reference stale/dropped database files
      # when running db:reset (which combines drop, create, and schema:load in one process).
      ActiveRecord::Base.connection_handler.clear_all_connections!

      schema_file = Rails.root.join("db/schema.rb").to_s

      for_each_tenant do |_tenant, pool|
        # Non-first tenants set `schema_dump: false`, so Rails has no dump path
        # and load_schema no-ops. Always load the shared schema.rb.
        ActiveRecord::Tasks::DatabaseTasks.load_schema(pool.db_config, :ruby, schema_file)
      end

      # Clear schema cache and reset column information to avoid stale cache
      # when db:seed runs after schema load (e.g. during db:reset)
      ActiveRecord::Base.descendants.each do |model|
        model.reset_column_information
      rescue ActiveRecord::ConnectionNotDefined
        # Ignore models with shards not defined in this environment (e.g. queue)
      end
    end
  end

  # db:prepare only loads schema.rb into tenants with a schema dump (the first
  # one in development) and migrates the others from scratch, which fails on the
  # post-squash migrations. Load schema.rb into those first; Rails still creates,
  # loads and seeds the first tenant itself.
  namespace :prepare do
    task tenants: :load_config do
      ensure_tenant_databases_initialized(except_schema_dump: true)
    end
  end
  Rake::Task["db:prepare"].enhance([ "db:prepare:tenants" ])

  Rake::Task["db:load_config"].enhance do
    Tenant.require_match!
  end

  # Override db:migrate so new / empty tenant DBs get schema.rb before migrate_all.
  # Skips seeds — Organization is created manually when onboarding a tenant.
  Rake::Task["db:migrate"].clear

  desc "Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)"
  task migrate: :load_config do
    ensure_tenant_databases_initialized
    ActiveRecord::Tasks::DatabaseTasks.migrate_all
    Rake::Task["db:_dump"].invoke
  end

  # Override db:rollback to rollback all tenant databases like db:migrate does.
  # Rails' default db:rollback raises an error for multi-database applications.
  Rake::Task["db:rollback"].clear

  desc "Roll the schema back to the previous version for all tenants (specify steps w/ STEP=n)"
  task rollback: :load_config do
    raise "VERSION is not supported - To rollback a specific version, use db:migrate:down" if ENV["VERSION"]

    step = ENV["STEP"] ? ENV["STEP"].to_i : 1

    for_each_tenant do |_tenant, pool|
      pool.migration_context.rollback(step)
    end

    Rake::Task["db:_dump"].invoke
  end

  # Override db:migrate:down to run down migration on all tenant databases.
  # Rails' default db:migrate:down raises an error for multi-database applications.
  Rake::Task["db:migrate:down"].clear

  namespace :migrate do
    desc "Run the \"down\" for a given migration VERSION on all tenants"
    task down: :load_config do
      raise "VERSION is required - To go down one migration, use db:rollback" if !ENV["VERSION"] || ENV["VERSION"].empty?

      ActiveRecord::Tasks::DatabaseTasks.check_target_version

      for_each_tenant do |_tenant, pool|
        pool.migration_context.run(:down, ActiveRecord::Tasks::DatabaseTasks.target_version)
      end

      Rake::Task["db:_dump"].invoke
    end
  end
end
