# frozen_string_literal: true

require "fileutils"

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

  # S3 replica keys: <path>/0000/*.ltx, <path>/0009/*.ltx (%04x)
  # File replica:    <path>/ltx/0/*.ltx, <path>/ltx/9/*.ltx
  S3_LEVEL_DIR = /\A[0-9a-f]{4}\z/i

  # rclone mirror (S3 layout) vs materialized restore tree (file layout)
  MIRROR_DIR = "litestream"
  RESTORE_DIR = "litestream-restore"

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

  # Local restore config points at litestream-restore/ (file layout), not the B2 mirror.
  def local(backup_path:, db_names:)
    {
      "dbs" => db_names.map { |name|
        {
          "path" => name,
          "replica" => {
            "path" => "#{backup_path}/#{RESTORE_DIR}/#{name}"
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

  def mirror_replica_path(backup_path, name)
    "#{backup_path}/#{MIRROR_DIR}/#{name}"
  end

  def restore_replica_path(backup_path, name)
    "#{backup_path}/#{RESTORE_DIR}/#{name}"
  end

  # Materialize file layout from mirror → restore for each tenant. Mirror is never modified.
  def prepare_local_replicas!(backup_path, db_names)
    Array(db_names).sum { |name|
      materialize_file_replica!(
        mirror_replica_path(backup_path, name),
        restore_replica_path(backup_path, name))
    }
  end

  def materialize_file_replica!(source_path, dest_path)
    return 0 unless Dir.exist?(source_path)

    FileUtils.rm_rf(dest_path)
    FileUtils.mkdir_p(dest_path)

    linked = 0
    Dir.children(source_path).each do |name|
      src = File.join(source_path, name)

      if name.match?(S3_LEVEL_DIR) && File.directory?(src)
        level = name.to_i(16)
        dest_level = File.join(dest_path, "ltx", level.to_s)
        FileUtils.mkdir_p(dest_level)
        Dir.children(src).each do |file|
          next unless file.end_with?(".ltx")

          link_or_copy!(File.join(src, file), File.join(dest_level, file))
          linked += 1
        end
      elsif name == "ltx" && File.directory?(src)
        FileUtils.mkdir_p(File.join(dest_path, "ltx"))
        FileUtils.cp_r(File.join(src, "."), File.join(dest_path, "ltx"))
        linked += 1
      elsif name == "generations" && File.directory?(src)
        FileUtils.cp_r(src, File.join(dest_path, "generations"))
      end
    end

    linked
  end

  def link_or_copy!(from, to)
    FileUtils.ln(from, to, force: true)
  rescue Errno::EXDEV, Errno::EPERM
    FileUtils.cp(from, to, preserve: true)
  end
end
