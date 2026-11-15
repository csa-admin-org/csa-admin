# frozen_string_literal: true

require "open3"

module Scheduled
  class DatabaseVacuumJob < BaseJob
    limits_concurrency key: ->(*) { "database-vacuum" }

    # sqlite3_step holds the GVL, which stalls queue BEGIN IMMEDIATE.
    def perform
      vacuum_file(tenant_database_path)
    end

    def vacuum_file(path)
      output, status = Open3.capture2e(
        "sqlite3", "-cmd", ".timeout 10000", path.to_s, "VACUUM")
      return if status.success?

      raise "VACUUM #{File.basename(path)} failed (#{status.exitstatus}): #{output.strip}"
    end

    private

    def tenant_database_path
      ActiveRecord::ConnectionAdapters::SQLite3Adapter.resolve_path(
        ApplicationRecord.connection_db_config.database)
    end
  end
end
