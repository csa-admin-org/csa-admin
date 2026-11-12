# frozen_string_literal: true

namespace :anonymized_dump do
  desc "Anonymize tenant databases in place (TENANT=name1,name2). Development only."
  task anonymize: :environment do
    raise "Only run this task in dev!" unless Rails.env.development?

    anonymized_dump_tenants.each do |tenant|
      Tenant.switch(tenant) do
        AnonymizedDump::Anonymizer.call(reindex: true, vacuum: true)
        AnonymizedDump::Verifier.call!
      end
      puts "Anonymized #{tenant}"
    end
  end

  desc "Verify the current tenant database. Development only. TENANT=name"
  task verify: :environment do
    raise "Only run this task in dev!" unless Rails.env.development?

    Tenant.switch_each(anonymized_dump_tenants) do |tenant|
      AnonymizedDump::Verifier.call!
      puts "Verified #{tenant}"
    end
  end

  desc "TODO: restore a Litestream replica to a scratch file. Needs replica read credentials."
  task :restore_replica, [ :tenant ] => :environment do |_task, args|
    raise "Only run this task in dev!" unless Rails.env.development?

    tenant = args[:tenant].presence || ENV["TENANT"].to_s.split(",").first
    raise "Pass a tenant: anonymized_dump:restore_replica[name]" if tenant.blank?

    output = Rails.root.join("tmp", "anonymized", "#{tenant}.sqlite3")
    AnonymizedDump::LitestreamRestore.call(tenant: tenant, output: output)
  end

  desc "TODO: upload a gzipped anonymized sqlite. Needs the anonymized bucket write key."
  task :publish, [ :tenant ] => :environment do |_task, args|
    raise "Only run this task in dev!" unless Rails.env.development?

    tenant = args[:tenant].presence || ENV["TENANT"].to_s.split(",").first
    raise "Pass a tenant: anonymized_dump:publish[name]" if tenant.blank?

    gzip = Rails.root.join("tmp", "anonymized", "#{tenant}.sqlite3.gz")
    AnonymizedDump::Publisher.upload!(tenant: tenant, gzip_path: gzip)
  end
end

namespace :development do
  desc "Fetch anonymized tenant DBs (names as args or TENANT=). Demo tenants stay put."
  task :restore_anonymized, [ :tenants ] => :environment do |_task, args|
    raise "Only run this task in dev!" unless Rails.env.development?

    names = [ args[:tenants], *args.extras ].compact.flat_map { |value| value.to_s.split(",") }
    names = ENV["TENANT"].to_s.split(",") if names.empty?
    names = names.map(&:strip).reject(&:blank?)
    if names.empty?
      raise "Pass tenants: bin/rails development:restore_anonymized[tenant1,tenant2]"
    end

    paths = AnonymizedDump::Restore.call(names)
    paths.each { |path| puts "Restored #{path}" }
    puts "Demo tenants were not changed. Restart the app if it is running."
  end
end

def anonymized_dump_tenants
  names = ENV["TENANT"].to_s.split(",").map(&:strip).reject(&:blank?)
  raise "Set TENANT=name1,name2" if names.empty?

  names
end
