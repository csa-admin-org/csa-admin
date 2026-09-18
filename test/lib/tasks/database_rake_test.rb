# frozen_string_literal: true

require "test_helper"
require "rake"
require "tmpdir"

class DatabaseRakeTest < ActiveSupport::TestCase
  # Opens a throwaway sqlite under Dir.mktmpdir. Transactional fixture teardown
  # would try to unpin that deleted path after the block returns.
  self.use_transactional_tests = false

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:migrate")
    Tenant.connect("acme")
  end

  teardown do
    Tenant.connect("acme")
  end

  test "uninitialized_tenant_database? is true with only system tables" do
    pool = stub_pool_with_tables(%w[schema_migrations ar_internal_metadata])

    assert uninitialized_tenant_database?(pool)
  end

  test "uninitialized_tenant_database? is true when the database is missing" do
    pool = Object.new
    pool.define_singleton_method(:with_connection) { raise ActiveRecord::NoDatabaseError }

    assert uninitialized_tenant_database?(pool)
  end

  test "uninitialized_tenant_database? is false once application tables exist" do
    pool = stub_pool_with_tables(%w[schema_migrations organizations members])

    assert_not uninitialized_tenant_database?(pool)
  end

  test "ensure_tenant_databases_initialized loads schema into empty tenant db" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "empty.sqlite3")
      create_empty_system_tables_sqlite(path)
      db_config = sqlite_hash_config("ensure_tmp", path)

      Tenant.stub(:all, [ "ensure_tmp" ]) do
        # Use Rails' temporary pool so the original acme connection is restored —
        # never clear_all_connections! (that poisons parallel workers).
        ActiveRecord::Tasks::DatabaseTasks.stub(
          :with_temporary_pool_for_each,
          ->(env: nil, name: nil, clobber: false, &block) {
            ActiveRecord::Tasks::DatabaseTasks.send(:with_temporary_pool, db_config, clobber: clobber, &block)
          }
        ) do
          out, = capture_io { ensure_tenant_databases_initialized }

          assert_includes out, "Loading schema for new tenant ensure_tmp..."
        end
      end

      tables = sqlite_table_names(path)
      assert_includes tables, "organizations"
      assert_includes tables, "shop_special_deliveries"
    end
  end

  private

  def stub_pool_with_tables(tables)
    connection = Object.new
    connection.define_singleton_method(:tables) { tables }

    pool = Object.new
    pool.define_singleton_method(:with_connection) { |&block| block.call(connection) }
    pool
  end

  def sqlite_hash_config(name, path)
    ActiveRecord::DatabaseConfigurations::HashConfig.new(
      "test",
      name,
      {
        "adapter" => "sqlite3",
        "database" => path,
        "migrations_paths" => "db/migrate",
        "schema_dump" => false
      })
  end

  def create_empty_system_tables_sqlite(path)
    SQLite3::Database.new(path) do |db|
      db.execute("CREATE TABLE schema_migrations (version varchar not null primary key)")
      db.execute(<<~SQL)
        CREATE TABLE ar_internal_metadata (
          key varchar not null primary key,
          value varchar,
          created_at datetime(6) not null,
          updated_at datetime(6) not null
        )
      SQL
    end
  end

  def sqlite_table_names(path)
    db = SQLite3::Database.new(path)
    db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
  ensure
    db&.close
  end
end
