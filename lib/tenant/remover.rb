# frozen_string_literal: true

require "aws-sdk-s3"

class Tenant::Remover
  RESERVED_NAMES = %w[queue].freeze
  TENANT_NAME_FORMAT = /\A[a-z0-9][a-z0-9_-]*\z/
  STORAGE_BUCKET = "csa-admin-storage"
  LITESTREAM_BUCKET = LitestreamConfig::DEFAULT_BUCKET

  attr_reader :tenant

  def initialize(tenant, confirm: nil, out: $stdout,
    cap_client: nil, storage_client: nil,
    litestream_client: nil)
    @tenant = validate_tenant!(tenant)
    @confirm = confirm.to_s
    @out = out
    @cap_client = cap_client
    @storage_client = storage_client
    @litestream_client = litestream_client
  end

  def confirmed?
    @confirm == @tenant
  end

  def configured?
    Tenant.configured?(@tenant)
  end

  def run
    mode = confirmed? ? "LIVE" : "DRY RUN"
    if configured?
      say "=== Tenant removal [#{mode}] — Phase 1 (pre-deploy): #{@tenant} ==="
      say ""
      print_backup_command
      say ""
      print_cloudflare_manual_step
      delete_cap_keys
      print_postmark_manual_step
      say ""
      print_phase_1_next_steps
    else
      say "=== Tenant removal [#{mode}] — Phase 2 (post-deploy): #{@tenant} ==="
      say "Make sure the deploy without '#{@tenant}' finished and " \
        "`bin/rails litestream:config` already ran."
      say ""
      clear_object_storage
      clear_litestream_replica
      say ""
      print_phase_2_next_steps
    end
  end

  def print_backup_command
    backup_dir = Rails.app.creds.option(:backup_path).presence || "<BACKUP_PATH>"
    remote_db = "/storage/csa-admin/production_#{@tenant}.sqlite3"
    remote_tmp = "/tmp/production_#{@tenant}.sqlite3"

    say "Backup command (run locally before deleting the DB on isle):"
    say "  ssh isle \"sqlite3 #{remote_db} \\\".backup '#{remote_tmp}'\\\"\" && \\"
    say "    scp isle:#{remote_tmp} \"#{backup_dir}/production_#{@tenant}.sqlite3\" && \\"
    say "    ssh isle \"rm -f #{remote_tmp}\""
  end

  def print_cloudflare_manual_step
    say "Cloudflare: run locally:"
    say "    bin/rails hostname:cloudflare:clear TENANT=#{@tenant} CONFIRM=#{@tenant}"
  end

  def delete_cap_keys
    client = cap_client
    all_keys = client.keys

    with_tenant_org(service: "Cap") do |org|
      org_site_key = org&.cap_site_key.presence
      matched = all_keys.select { |key|
        key["siteKey"] == org_site_key || key["name"] == @tenant
      }.uniq { |key| key.fetch("siteKey") }

      if matched.empty?
        if org_site_key
          if confirmed?
            org.update!(cap_site_key: nil, cap_secret_key: nil)
            say "⏭️  Cap: site key #{org_site_key} not found (already deleted); cleared org columns"
          else
            say "dry-run Cap: site key #{org_site_key} already missing; would clear org columns"
          end
        else
          say "⏭️  Cap: no site key found for '#{@tenant}' (skipped)"
        end
        next
      end

      matched.each do |key|
        site_key = key.fetch("siteKey")
        label = "#{site_key} (#{key["name"]})"
        if confirmed?
          begin
            client.delete_key(site_key)
            say "🗑️  Cap: deleted site key #{label}"
          rescue Cap::Client::NotFoundError
            say "⏭️  Cap: site key #{label} not found (already deleted)"
          end
        else
          say "dry-run Cap: would delete site key #{label}"
        end
      end

      if org_site_key && confirmed?
        org.update!(cap_site_key: nil, cap_secret_key: nil)
      end
    end
  end

  def print_postmark_manual_step
    domain = Tenant.configured_domain(@tenant)
    shared_domain = domain.present? && (
      domain == Rails.app.creds.option(:app_domain) ||
      Tenant.domain_shared?(domain, except: @tenant)
    )

    with_tenant_org(service: "Postmark") do |org|
      server_id = org&.postmark_server_id.presence
      if server_id
        parts = [ "server #{server_id}" ]
        parts << "domain #{domain}" if domain.present? && !shared_domain
        say "Postmark: delete #{parts.join(" and ")} manually at " \
          "https://account.postmarkapp.com/servers"
      else
        say "⏭️  Postmark: no server configured for '#{@tenant}' (skipped)"
        if domain.present? && !shared_domain
          say "Postmark: delete domain #{domain} manually at " \
            "https://account.postmarkapp.com/servers"
        end
      end
    end

    if shared_domain
      say "⏭️  Postmark: domain #{domain} is shared (keep it)"
    end
  end

  def clear_object_storage
    if configured?
      raise "Remove '#{@tenant}' from config/tenant.yml and deploy before clearing object storage"
    end

    clear_s3_prefix(client: storage_client, bucket: STORAGE_BUCKET, label: "Object storage")
  end

  def clear_litestream_replica
    if configured?
      raise "Remove '#{@tenant}' from config/tenant.yml, deploy, and run " \
        "`bin/rails litestream:config` before clearing Litestream replicas"
    end

    clear_s3_prefix(client: litestream_client, bucket: LITESTREAM_BUCKET, label: "Litestream")
  end

  private

  def validate_tenant!(name)
    value = name.to_s.strip
    raise ArgumentError, "TENANT environment variable is required" if value.blank?
    raise ArgumentError, "Invalid tenant name '#{value}'" unless value.match?(TENANT_NAME_FORMAT)
    raise ArgumentError, "Refusing to remove reserved name '#{value}'" if RESERVED_NAMES.include?(value)

    canonical = Tenant.find_with_aliases(value)
    if canonical && canonical.to_s != value
      raise ArgumentError, "'#{value}' is an alias for active tenant '#{canonical}'"
    end

    value
  end

  def with_tenant_org(service:)
    unless configured?
      yield nil
      return
    end

    unless tenant_db_exists?
      say "⚠️  #{service}: local database not found for '#{@tenant}' " \
        "(run via `kamal app exec -r job` to read live production DB)"
      yield nil
      return
    end

    Tenant.switch(@tenant) do
      org = Organization.table_exists? ? Organization.first : nil
      yield org
    end
  end

  def tenant_db_exists?
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: @tenant)
    return false unless db_config

    Pathname.new(db_config.database).expand_path(Rails.root).exist?
  end

  def clear_s3_prefix(client:, bucket:, label:)
    prefix = "#{@tenant}/"
    keys = []
    client.list_objects_v2(bucket: bucket, prefix: prefix).each do |page|
      page.contents.each { |obj| keys << obj.key }
    end

    if keys.empty?
      say "⏭️  #{label}: no objects in '#{bucket}/#{prefix}' (skipped)"
      return
    end

    unless confirmed?
      say "dry-run #{label}: would delete #{keys.size} object(s) from '#{bucket}/#{prefix}'"
      keys.first(10).each { |key| say "  - #{key}" }
      say "  ... and #{keys.size - 10} more" if keys.size > 10
      return
    end

    keys.each_slice(1000) do |batch|
      response = client.delete_objects(
        bucket: bucket,
        delete: { objects: batch.map { |key| { key: key } } })
      if response.errors.any?
        failed = response.errors.map { |err| "#{err.key} (#{err.code}: #{err.message})" }.join(", ")
        raise "#{label} delete failed for '#{bucket}/#{prefix}': #{failed}"
      end
    end

    say "🗑️  #{label}: deleted #{keys.size} object(s) from '#{bucket}/#{prefix}'"
  end

  def cap_client
    @cap_client ||= Cap::Client.new
  end

  def storage_client
    @storage_client ||= begin
      creds = Rails.application.credentials.dig(:object_store, :production)
      raise "Missing object_store.production credentials" unless creds

      Aws::S3::Client.new(
        endpoint: normalize_s3_endpoint(creds[:endpoint]),
        access_key_id: creds[:access_key_id],
        secret_access_key: creds[:secret_access_key],
        region: creds[:region] || "auto",
        request_checksum_calculation: "when_required",
        response_checksum_validation: "when_required")
    end
  end

  def litestream_client
    @litestream_client ||= begin
      creds = Rails.application.credentials.litestream
      raise "Missing litestream credentials" unless creds

      Aws::S3::Client.new(
        endpoint: normalize_s3_endpoint(creds[:endpoint]),
        access_key_id: creds[:access_key_id],
        secret_access_key: creds[:secret_access_key],
        region: creds[:region] || extract_s3_region(creds[:endpoint]) || "us-east-1",
        force_path_style: true,
        request_checksum_calculation: "when_required",
        response_checksum_validation: "when_required")
    end
  end

  def normalize_s3_endpoint(endpoint)
    value = endpoint.to_s
    value.match?(%r{\Ahttps?://}) ? value : "https://#{value}"
  end

  def extract_s3_region(endpoint)
    endpoint.to_s[/s3\.([a-z0-9-]+)\./, 1]
  end

  def print_phase_1_next_steps
    unless confirmed?
      say "Re-run with CONFIRM=#{@tenant} to execute Phase 1."
      say ""
    end

    say "Next manual steps after Phase 1:"
    say "  1. Confirm the final DB backup is saved locally."
    say "  2. Clear Cloudflare custom hostnames locally:"
    say "     bin/rails hostname:cloudflare:clear TENANT=#{@tenant} CONFIRM=#{@tenant}"
    say "  3. Remove '#{@tenant}' from config/tenant.yml, commit, push, and deploy."
    say "  4. After that deploy, delete the Postmark server " \
      "(and unshared domain) at https://account.postmarkapp.com/servers"
    say "  5. Run `bin/rails litestream:config` locally."
    say "  6. Delete DB files on isle:"
    say "     ssh isle \"rm -f /storage/csa-admin/production_#{@tenant}.sqlite3 " \
      "/storage/csa-admin/production_#{@tenant}.sqlite3-wal " \
      "/storage/csa-admin/production_#{@tenant}.sqlite3-shm\""
    say "  7. Run Phase 2 locally to clear object storage and Litestream replicas:"
    say "     bin/rails tenant:remove TENANT=#{@tenant}"
    say "     bin/rails tenant:remove TENANT=#{@tenant} CONFIRM=#{@tenant}"
  end

  def print_phase_2_next_steps
    unless confirmed?
      say "Re-run with CONFIRM=#{@tenant} to execute Phase 2."
      say ""
    end

    say "Final manual steps:"
    say "  1. Clean local dev files: rm -f storage/development_#{@tenant}.sqlite3* && " \
      "rm -rf storage/#{@tenant}"
    say "  2. Regenerate bookmarks: bin/rails bookmarks"
    say "  3. Ask the organization to remove their DNS records " \
      "(admin/members CNAMEs, ACME TXT, Postmark DKIM TXT + Return-Path CNAME)."
  end

  def say(message)
    @out.puts(message)
  end
end
