# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "rake"
require "tmpdir"
require "yaml"

class LitestreamRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("litestream:restore")
    Rake::Task["litestream:restore"].reenable
    Rake::Task["litestream:config:local"].reenable if Rake::Task.task_defined?("litestream:config:local")
  end

  test "restore reports all tenants without listing them" do
    out, = run_restore

    assert_includes out, "Restoring litestream backups for all tenants..."
    assert_not_includes out, "acme, demo"
  end

  test "restore reports selected tenants" do
    out, = run_restore(tenant: "acme,demo")

    assert_includes out, "Restoring litestream backups for: acme, demo"
  end

  test "local config uses singular replica and no snapshot-interval" do
    Dir.mktmpdir do |dir|
      with_env("BACKUP_PATH" => dir) do
        with_rails_env("development") do
          Tenant.stub(:all, %w[acme demo]) do
            Rake::Task["litestream:config:local"].invoke
          end
        end
      end

      config = YAML.safe_load(File.read(File.join(dir, "litestream.yml")))

      assert_equal %w[acme demo], config["dbs"].map { |db| db["path"] }
      config["dbs"].each do |db|
        assert db.key?("replica"), "expected singular replica key"
        assert_not db.key?("replicas"), "v0.3 replicas array must not be generated"
        assert_not db["replica"].key?("snapshot-interval")
        assert_equal "#{dir}/litestream/#{db["path"]}", db["replica"]["path"]
      end
    end
  end

  test "server config builder is litestream 0.5 shaped" do
    config = LitestreamConfig.server(
      volume_path: "/storage/csa-admin",
      db_names: %w[acme queue],
      access_key_id: "key",
      secret_access_key: "secret",
      endpoint: "s3.example.com")

    assert_equal "key", config["access-key-id"]
    assert_equal "secret", config["secret-access-key"]
    assert_equal "1h", config["sync-interval"]
    assert_equal "2m", config["shutdown-sync-timeout"]
    assert_equal({ "interval" => "24h", "retention" => "72h" }, config["snapshot"])
    assert_equal "info", config.dig("logging", "level")
    assert_equal "json", config.dig("logging", "type")

    assert_equal 2, config["dbs"].size

    acme = config["dbs"].find { |db| db["path"].end_with?("production_acme.sqlite3") }
    assert_equal "/storage/csa-admin/production_acme.sqlite3", acme["path"]
    assert acme.key?("replica")
    assert_not acme.key?("replicas")
    assert_equal "s3", acme["replica"]["type"]
    assert_equal "csa-admin-litestream", acme["replica"]["bucket"]
    assert_equal "acme", acme["replica"]["path"]
    assert_equal "s3.example.com", acme["replica"]["endpoint"]
    assert_equal "1h", acme["replica"]["sync-interval"]
    assert_not acme["replica"].key?("snapshot-interval")

    queue = config["dbs"].find { |db| db["path"].end_with?("production_queue.sqlite3") }
    assert_equal "queue", queue["replica"]["path"]
  end

  test "merge_host_config replaces only volume-prefixed dbs and applies new globals" do
    existing = {
      "access-key-id" => "old",
      "sync-interval" => "1s",
      "dbs" => [
        { "path" => "/storage/other-app/db.sqlite3", "replica" => { "path" => "other" } },
        { "path" => "/storage/csa-admin/production_old.sqlite3", "replicas" => [ { "path" => "old" } ] }
      ]
    }
    generated = LitestreamConfig.server(
      volume_path: "/storage/csa-admin",
      db_names: %w[acme],
      access_key_id: "new",
      secret_access_key: "secret",
      endpoint: "s3.example.com")

    merged = LitestreamConfig.merge_host_config(existing, generated, volume_path: "/storage/csa-admin")

    assert_equal "new", merged["access-key-id"]
    assert_equal "1h", merged["sync-interval"]
    assert_equal({ "interval" => "24h", "retention" => "72h" }, merged["snapshot"])
    paths = merged["dbs"].map { |db| db["path"] }
    assert_includes paths, "/storage/other-app/db.sqlite3"
    assert_includes paths, "/storage/csa-admin/production_acme.sqlite3"
    assert_not_includes paths, "/storage/csa-admin/production_old.sqlite3"
  end

  test "merge_host_config uses path boundary so sibling volumes stay" do
    existing = {
      "dbs" => [
        { "path" => "/storage/csa-admin-other/db.sqlite3", "replica" => { "path" => "sibling" } },
        { "path" => "/storage/csa-admin/production_old.sqlite3", "replica" => { "path" => "old" } }
      ]
    }
    generated = LitestreamConfig.server(
      volume_path: "/storage/csa-admin",
      db_names: %w[acme],
      access_key_id: "new",
      secret_access_key: "secret",
      endpoint: "s3.example.com")

    merged = LitestreamConfig.merge_host_config(existing, generated, volume_path: "/storage/csa-admin")
    paths = merged["dbs"].map { |db| db["path"] }

    assert_includes paths, "/storage/csa-admin-other/db.sqlite3"
    assert_includes paths, "/storage/csa-admin/production_acme.sqlite3"
    assert_not_includes paths, "/storage/csa-admin/production_old.sqlite3"
  end

  private

  def run_restore(tenant: nil)
    Dir.mktmpdir do |dir|
      with_env("BACKUP_PATH" => dir, "TENANT" => tenant) do
        with_rails_env("development") do
          Rails.stub(:root, Pathname(dir)) do
            Tenant.stub(:all, %w[acme demo]) do
              Parallel.stub(:each, ->(*) { }) do
                capture_io { Rake::Task["litestream:restore"].invoke }
              end
            end
          end
        end
      end
    end
  end
end
