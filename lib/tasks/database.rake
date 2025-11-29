# frozen_string_literal: true

def for_each_tenant
  Tenant.all.each do |tenant|
    puts "#{tenant}..."
    ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: tenant) do |pool|
      yield tenant, pool
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

      for_each_tenant do |_tenant, pool|
        db_config = pool.db_config
        ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, db_config.schema_format)
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
