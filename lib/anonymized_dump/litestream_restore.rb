# frozen_string_literal: true

module AnonymizedDump
  # TODO: wire this once a read-only replica key exists. It must not run on
  # the app server against the live SQLite files.
  #
  # litestream restore reads the B2 replica and writes only the -o path. Omit
  # -o and it restores onto the path in the config, which in production is
  # /storage/csa-admin/production_<tenant>.sqlite3. Always pass a scratch file.
  # Do not replicate or publish the queue database.
  class LitestreamRestore
    def self.call(tenant:, output:)
      name = AnonymizedDump.tenant_name!(tenant)
      raise NotImplementedError, <<~MSG
        Litestream restore is not wired (no replica credentials in this environment).
        Restore #{name} to #{output} with `litestream restore -o` from a v0.5
        replica config. Do not omit -o and do not use the live database path.
        See docs/anonymized_dumps.md.
      MSG
    end
  end
end
