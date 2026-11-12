# frozen_string_literal: true

require "fileutils"
require "stringio"
require "zlib"

module AnonymizedDump
  # Downloads one already-anonymized tenant database for a development VM.
  # Credentials are a read-only key on the anonymized bucket, never the
  # Litestream replica. Set ANONYMIZED_DUMPS_LOCAL_DIR to skip the network.
  class Restore
    ENV_KEYS = %w[
      ANONYMIZED_DUMPS_BUCKET
      ANONYMIZED_DUMPS_ENDPOINT
      ANONYMIZED_DUMPS_ACCESS_KEY_ID
      ANONYMIZED_DUMPS_SECRET_ACCESS_KEY
    ].freeze

    def self.call(tenants, root: Rails.root.join("storage"), client: nil)
      raise Error, "Refusing to restore anonymized dumps in production" if Rails.env.production?

      Array(tenants).map { |tenant| install(tenant, root: Pathname(root), client: client) }
    end

    def self.install(tenant, root:, client: nil)
      name = AnonymizedDump.tenant_name!(tenant)
      if name.match?(Tenant::DEMO_TENANT_PATTERN)
        raise Error, "refusing to overwrite demo tenant #{name}"
      end
      raise Error, "unknown tenant #{name}" unless Tenant.exists?(name)

      dest = root.join("development_#{name}.sqlite3")
      FileUtils.mkdir_p(dest.dirname)
      remove_sidecars(dest)
      FileUtils.rm_f(dest)

      if ENV["ANONYMIZED_DUMPS_LOCAL_DIR"].present?
        copy_local(name, dest)
      else
        download(name, dest, client: client)
      end
      dest
    end

    def self.copy_local(tenant, dest)
      directory = Pathname(ENV.fetch("ANONYMIZED_DUMPS_LOCAL_DIR"))
      source = directory.join("#{tenant}.sqlite3")
      gzip = directory.join("#{tenant}.sqlite3.gz")
      if source.file?
        FileUtils.cp(source, dest)
      elsif gzip.file?
        write_gzip(File.binread(gzip), dest)
      else
        raise Error, "no local anonymized dump for #{tenant} in #{directory}"
      end
    end

    def self.download(tenant, dest, client:)
      missing = ENV_KEYS.reject { |key| ENV[key].present? }
      if missing.any?
        raise Error, "missing #{missing.join(", ")} (read-only key on the anonymized bucket)"
      end

      key = Publisher.object_keys(tenant, date: Date.current).fetch(:latest)
      response = (client || s3_client).get_object(bucket: ENV.fetch("ANONYMIZED_DUMPS_BUCKET"), key: key)
      bytes = response.body.respond_to?(:read) ? response.body.read : response.body.to_s
      write_bytes(bytes, dest)
    end

    def self.write_bytes(bytes, dest)
      if bytes.unpack1("n") == 0x1f8b
        write_gzip(bytes, dest)
      else
        File.binwrite(dest, bytes)
      end
    end

    def self.write_gzip(bytes, dest)
      File.binwrite(dest, Zlib::GzipReader.new(StringIO.new(bytes)).read)
    end

    def self.remove_sidecars(dest)
      %w[-wal -shm -journal].each { |suffix| FileUtils.rm_f("#{dest}#{suffix}") }
    end

    def self.s3_client
      require "aws-sdk-s3"
      Aws::S3::Client.new(
        endpoint: ENV.fetch("ANONYMIZED_DUMPS_ENDPOINT"),
        access_key_id: ENV.fetch("ANONYMIZED_DUMPS_ACCESS_KEY_ID"),
        secret_access_key: ENV.fetch("ANONYMIZED_DUMPS_SECRET_ACCESS_KEY"),
        region: ENV.fetch("ANONYMIZED_DUMPS_REGION", "auto"),
        request_checksum_calculation: "when_required",
        response_checksum_validation: "when_required")
    end
    private_class_method :copy_local, :download, :write_bytes, :write_gzip, :remove_sidecars, :s3_client, :install
  end
end
