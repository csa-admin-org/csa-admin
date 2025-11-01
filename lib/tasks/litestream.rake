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
      replica_config = {
        "type" => "s3",
        "bucket" => "csa-admin-litestream",
        "endpoint" => s3_credentials.endpoint,
        "sync-interval" => "1h"
      }
      db_names = Tenant.all + [ "queue" ]
      config = {
        "access-key-id" => s3_credentials.access_key_id,
        "secret-access-key" => s3_credentials.secret_access_key,
        "dbs" => db_names.map { |name|
          {
            "path" => "#{volume_path}/production_#{name}.sqlite3",
            "replicas" => [
              { "path" => name }.merge(replica_config)
            ]
          }
        }
      }

      host = SSHKit::Host.new(
        hostname: kamal.raw_config.dig("servers", "web").first,
        user: kamal.ssh.user)

      on host do
        if test("[ -f /etc/litestream.yml ]")
          existing_yaml = capture("sudo cat /etc/litestream.yml")
          existing_config = YAML.safe_load(existing_yaml)
          config = existing_config.merge(config) do |key, old_val, new_val|
            if key == "dbs"
              (old_val.reject { |db| db["path"].start_with?(volume_path) } + new_val)
            else
              new_val
            end
          end
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
      backup_path = ENV["BACKUP_PATH"]

      config = {
        "dbs" => Tenant.all.map { |name|
          {
            "path" => name,
            "replicas" => [
              "path" => "#{backup_path}/litestream/#{name}"
            ]
          }
        }
      }

      File.write("#{backup_path}/litestream.yml", config.to_yaml)
    end
  end

  task :config do
    Rake::Task["litestream:config:server"].invoke
    Rake::Task["litestream:config:local"].invoke
  end

  desc "Restore litestream backups to local storage"
  task restore: :environment do
    raise "Only run this task in dev!" unless Rails.env.development?

    `rm #{Rails.root.join("storage", "development_*")}`
    Parallel.each(Tenant.all) do |tenant|
      `litestream restore --config "#{ENV["BACKUP_PATH"]}/litestream.yml" -o "#{Rails.root.join("storage", "development_#{tenant}.sqlite3")}" #{tenant}`
    end

    puts "Litestream backups restored successfully."
  end
end
