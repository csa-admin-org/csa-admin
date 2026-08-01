# frozen_string_literal: true

require "kamal"
require "sshkit"
require "sshkit/dsl"
require "yaml"
require "parallel"
require "fileutils"
require "stringio"

include SSHKit::DSL

namespace :litestream do
  namespace :config do
    desc "Update production litestream config and restart litestream"
    task server: :environment do
      raise "Only run this task in dev!" unless Rails.env.development?

      kamal = Kamal::Configuration.create_from(config_file: Rails.root.join("config/deploy.yml"))
      volume_path = kamal.raw_config["volumes"].first.split(":").first
      s3_credentials = Rails.application.credentials.litestream
      config = LitestreamConfig.server(
        volume_path: volume_path,
        db_names: Tenant.all + [ "queue" ],
        access_key_id: s3_credentials.access_key_id,
        secret_access_key: s3_credentials.secret_access_key,
        endpoint: s3_credentials.endpoint)

      host = SSHKit::Host.new(
        hostname: kamal.raw_config.dig("servers", "web").first,
        user: kamal.ssh.user)

      on host do
        if test("[ -f /etc/litestream.yml ]")
          existing_yaml = capture("sudo cat /etc/litestream.yml")
          existing_config = YAML.safe_load(existing_yaml) || {}
          config = LitestreamConfig.merge_host_config(existing_config, config, volume_path: volume_path)
        end

        temp_file = "/tmp/litestream.yml.tmp"
        upload! StringIO.new(config.to_yaml), temp_file
        execute :sudo, :mv, temp_file, "/etc/litestream.yml"
        execute :sudo, :chmod, "640", "/etc/litestream.yml"
        execute :sudo, :chown, "root:root", "/etc/litestream.yml"

        execute :sudo, :systemctl, :restart, "litestream.service"

        if test("systemctl is-active litestream.service")
          puts "Litestream restarted successfully."
        else
          raise "Failed to restart Litestream!"
        end
      end
    end

    desc "Update local litestream config used to restore backups for development"
    task local: :environment do
      raise "Only run this task in dev!" unless Rails.env.development?

      backup_path = ENV.fetch("BACKUP_PATH")
      config = LitestreamConfig.local(backup_path: backup_path, db_names: Tenant.all)
      File.write("#{backup_path}/litestream.yml", config.to_yaml)
    end
  end

  task :config do
    Rake::Task["litestream:config:server"].invoke
    Rake::Task["litestream:config:local"].invoke
  end

  desc "Restore litestream backups to local storage (optional TENANT=name1,name2)"
  task restore: :environment do
    raise "Only run this task in dev!" unless Rails.env.development?

    tenants = Tenant.all
    if ENV["TENANT"].present?
      puts "Restoring litestream backups for: #{tenants.join(", ")}"
    else
      puts "Restoring litestream backups for all tenants..."
    end

    # Only remove DBs for tenants being restored so TENANT=… leaves others intact
    tenants.each do |tenant|
      FileUtils.rm_f(Dir.glob(Rails.root.join("storage", "development_#{tenant}.sqlite3*")))
    end

    backup_path = ENV.fetch("BACKUP_PATH")
    backup_config = "#{backup_path}/litestream.yml"

    # Materialize litestream-restore/ (file layout) from litestream/ (S3 mirror).
    # Mirror is never rewritten so rclone can incremental-sync cleanly.
    moved = LitestreamConfig.prepare_local_replicas!(backup_path, tenants)
    puts "Materialized file-layout restore tree (#{moved} LTX files)" if moved.positive?

    Parallel.each(tenants) do |tenant|
      output = Rails.root.join("storage", "development_#{tenant}.sqlite3")
      ok = system(
        "litestream", "restore",
        "--config", backup_config,
        "-o", output.to_s,
        tenant)
      raise "litestream restore failed for #{tenant}" unless ok
    end

    # Remove WAL-mode journal files created during restore
    tenants.each do |tenant|
      FileUtils.rm_f(Dir.glob(Rails.root.join("storage", "development_#{tenant}.sqlite3.tmp-shm")))
      FileUtils.rm_f(Dir.glob(Rails.root.join("storage", "development_#{tenant}.sqlite3.tmp-wal")))
    end

    puts "Litestream backups restored successfully."
  end
end
