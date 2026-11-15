# frozen_string_literal: true

require "test_helper"

class Scheduled::DatabaseVacuumJobTest < ActiveJob::TestCase
  test "limits concurrency globally" do
    job = Scheduled::DatabaseVacuumJob.new

    assert_equal 1, Scheduled::DatabaseVacuumJob.concurrency_limit
    assert_equal "Scheduled::DatabaseVacuumJob/database-vacuum", job.concurrency_key
  end

  test "vacuums the current tenant database in a subprocess" do
    path = ActiveRecord::ConnectionAdapters::SQLite3Adapter.resolve_path(
      ApplicationRecord.connection_db_config.database)
    calls = []
    status = Struct.new(:success?, :exitstatus).new(true, 0)

    Open3.stub(:capture2e, ->(*args) {
      calls << args
      [ "", status ]
    }) do
      Scheduled::DatabaseVacuumJob.perform_later
      perform_enqueued_jobs
    end

    assert_equal [ [ "sqlite3", "-cmd", ".timeout 10000", path, "VACUUM" ] ], calls
  end

  test "raises when sqlite3 vacuum fails" do
    status = Struct.new(:success?, :exitstatus).new(false, 5)

    Open3.stub(:capture2e, [ "Error: database is locked\n", status ]) do
      error = assert_raises(RuntimeError) do
        Scheduled::DatabaseVacuumJob.new.vacuum_file("/rails/storage/production_acme.sqlite3")
      end

      assert_match(/production_acme\.sqlite3/, error.message)
      assert_match(/database is locked/, error.message)
    end
  end

  test "sqlite3 vacuum keeps existing rows" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "tenant.sqlite3")
      SQLite3::Database.new(path) do |db|
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("CREATE TABLE items (id integer)")
        db.execute("INSERT INTO items VALUES (1)")
      end

      Scheduled::DatabaseVacuumJob.new.vacuum_file(path)

      SQLite3::Database.new(path) do |db|
        assert_equal 1, db.get_first_value("SELECT COUNT(*) FROM items")
      end
    end
  end
end
