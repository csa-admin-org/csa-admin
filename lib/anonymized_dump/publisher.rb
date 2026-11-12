# frozen_string_literal: true

require "zlib"

module AnonymizedDump
  # Gzip is local. The B2 put is intentionally unimplemented until a write key
  # exists for a bucket that is not the Litestream replica bucket.
  class Publisher
    def self.object_keys(tenant, date:)
      name = AnonymizedDump.tenant_name!(tenant)
      {
        dated: "tenants/#{name}/#{date.iso8601}.sqlite3.gz",
        latest: "tenants/#{name}/latest.sqlite3.gz"
      }
    end

    def self.retention_days
      Classification.load.retention_days
    end

    def self.compress(source, dest)
      File.open(source, "rb") do |file|
        Zlib::GzipWriter.open(dest) do |gzip|
          IO.copy_stream(file, gzip)
        end
      end
      dest
    end

    # TODO: put object_keys to the anonymized bucket with a write-only key.
    # Dated keys expire via a bucket lifecycle of retention_days. `latest` is
    # overwritten each run. Do not grant this key any access to the replica
    # bucket, and do not grant the replica key any access to this bucket.
    def self.upload!(tenant:, gzip_path:, date: Date.current)
      keys = object_keys(tenant, date: date)
      raise NotImplementedError, <<~MSG
        B2 upload is not wired. #{gzip_path} would be written to #{keys[:dated]}
        and #{keys[:latest]} using ANONYMIZED_DUMPS_* write credentials.
        Keep #{retention_days} dated objects with a bucket lifecycle rule.
        See docs/anonymized_dumps.md.
      MSG
    end
  end
end
