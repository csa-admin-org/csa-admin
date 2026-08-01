# frozen_string_literal: true

# Pure builders for Litestream v0.5.x config (testable without SSH).
module LitestreamConfig
  SNAPSHOT = {
    "interval" => "24h",
    "retention" => "72h"
  }.freeze

  SERVER_DEFAULTS = {
    "sync-interval" => "1h",
    "shutdown-sync-timeout" => "2m",
    "logging" => {
      "level" => "info",
      "type" => "json"
    },
    "snapshot" => SNAPSHOT
  }.freeze

  module_function

  def server(volume_path:, db_names:, access_key_id:, secret_access_key:, endpoint:,
    bucket: "csa-admin-litestream")
    replica_defaults = {
      "type" => "s3",
      "bucket" => bucket,
      "endpoint" => endpoint,
      "sync-interval" => "1h"
    }

    SERVER_DEFAULTS.merge(
      "access-key-id" => access_key_id,
      "secret-access-key" => secret_access_key,
      "dbs" => db_names.map { |name|
        {
          "path" => "#{volume_path}/production_#{name}.sqlite3",
          "replica" => replica_defaults.merge("path" => name)
        }
      }
    )
  end

  def local(backup_path:, db_names:)
    {
      "dbs" => db_names.map { |name|
        {
          "path" => name,
          "replica" => {
            "path" => "#{backup_path}/litestream/#{name}"
          }
        }
      }
    }
  end

  # Keep non-csa-admin DB entries when rewriting /etc/litestream.yml on a shared host.
  def merge_host_config(existing, generated, volume_path:)
    existing.merge(generated) do |key, old_val, new_val|
      if key == "dbs"
        prefix = volume_path.end_with?("/") ? volume_path : "#{volume_path}/"
        old_val.reject { |db| db["path"].to_s.start_with?(prefix) } + new_val
      else
        new_val
      end
    end
  end
end
