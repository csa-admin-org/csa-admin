# frozen_string_literal: true

module AnonymizedDump
  # Nightly order. Replica restore and upload raise until credentials exist.
  # The middle (anonymize, verify, gzip) runs on a database that is already local.
  class Pipeline
    STEPS = %i[restore_replica anonymize verify vacuum compress upload heartbeat].freeze

    def self.heartbeat
      # TODO: Appsignal::CheckIn.cron("anonymized-dumps") after a full success.
      # A failed tenant must not check in, so a missed night pages.
      return unless ENV["ANONYMIZED_DUMP_HEARTBEAT"] == "1"
      return unless defined?(Appsignal::CheckIn)

      Appsignal::CheckIn.cron("anonymized-dumps")
    end

    def self.run!(tenant, vacuum: false, reindex: true)
      raise Error, "Refusing to anonymize in production" if Rails.env.production?

      output = Rails.root.join("tmp", "anonymized", "#{AnonymizedDump.tenant_name!(tenant)}.sqlite3")
      LitestreamRestore.call(tenant: tenant, output: output)
      Tenant.switch(tenant) do
        Anonymizer.call(reindex: reindex, vacuum: vacuum)
        Verifier.call!
      end
      gzip = Publisher.compress(output, "#{output}.gz")
      Publisher.upload!(tenant: tenant, gzip_path: gzip)
      heartbeat
    end
  end
end
