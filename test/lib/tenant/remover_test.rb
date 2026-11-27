# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"

class Tenant::RemoverTest < ActiveSupport::TestCase
  test "rejects blank, malformed, reserved, and alias tenant names" do
    assert_raises(ArgumentError) { Tenant::Remover.new("") }
    assert_raises(ArgumentError) { Tenant::Remover.new(nil) }
    assert_raises(ArgumentError) { Tenant::Remover.new("acme,beta") }
    assert_raises(ArgumentError) { Tenant::Remover.new("../acme") }
    assert_raises(ArgumentError) { Tenant::Remover.new("queue") }

    error = assert_raises(ArgumentError) { Tenant::Remover.new("ac") }
    assert_includes error.message, "alias for active tenant 'acme'"
  end

  test "is dry-run by default and confirms only on exact tenant match" do
    assert_not Tenant::Remover.new("acme").confirmed?
    assert_not Tenant::Remover.new("acme", confirm: "1").confirmed?
    assert_not Tenant::Remover.new("acme", confirm: "beta").confirmed?
    assert Tenant::Remover.new("acme", confirm: "acme").confirmed?
  end

  test "phase 1 dry-run inspects Cap without deleting or mutating org" do
    Current.org.update!(
      cap_site_key: "site-123",
      cap_secret_key: "secret-123",
      postmark_server_id: 4242,
      postmark_server_token: "pm-token")

    cap_list = stub_request(:get, "https://cap.test/server/keys")
      .to_return(status: 200, body: [ { siteKey: "site-123", name: "acme" } ].to_json)
    out = StringIO.new

    remover = Tenant::Remover.new(
      "acme",
      out: out,
      cap_client: Cap::Client.new(api_url: "https://cap.test", api_key: "api-key"))
    remover.run

    assert_requested cap_list

    Current.org.reload
    assert_equal "site-123", Current.org.cap_site_key
    assert_equal "4242", Current.org.postmark_server_id
    assert_equal "pm-token", Current.org.postmark_server_token

    output = out.string
    assert_includes output, "DRY RUN"
    assert_includes output, "Phase 1"
    assert_includes output, "production_acme.sqlite3"
    assert_includes output, "bin/rails hostname:cloudflare:clear TENANT=acme CONFIRM=acme"
    assert_includes output, "dry-run Cap: would delete site key site-123 (acme)"
    assert_includes output, "Postmark: delete server 4242 and domain acme.test manually at https://account.postmarkapp.com/servers"
    assert_includes output, "Re-run with CONFIRM=acme to execute Phase 1."
    assert_includes output, "rm -rf /storage/csa-admin/.production_acme.sqlite3-litestream"
    assert_not_includes output, "would delete custom hostname"
    assert_not_includes output, "would delete server"
    assert_not_includes output, "would delete domain"
  end

  test "phase 1 confirmed deletes Cap key and leaves Postmark credentials untouched" do
    Current.org.update!(
      cap_site_key: "site-123",
      cap_secret_key: "secret-123",
      postmark_server_id: 4242,
      postmark_server_token: "pm-token")

    stub_request(:get, "https://cap.test/server/keys")
      .to_return(status: 200, body: [ { siteKey: "site-123", name: "acme" } ].to_json)
    cap_delete = stub_request(:delete, "https://cap.test/server/keys/site-123")
      .to_return(status: 200, body: { success: true }.to_json)
    out = StringIO.new

    remover = Tenant::Remover.new(
      "acme",
      confirm: "acme",
      out: out,
      cap_client: Cap::Client.new(api_url: "https://cap.test", api_key: "api-key"))
    remover.run

    assert_requested cap_delete

    Current.org.reload
    assert_nil Current.org.cap_site_key
    assert_nil Current.org.cap_secret_key
    assert_equal "4242", Current.org.postmark_server_id
    assert_equal "pm-token", Current.org.postmark_server_token

    output = out.string
    assert_includes output, "LIVE"
    assert_includes output, "deleted site key site-123"
    assert_includes output, "bin/rails hostname:cloudflare:clear TENANT=acme CONFIRM=acme"
    assert_includes output, "Postmark: delete server 4242 and domain acme.test manually at https://account.postmarkapp.com/servers"
    assert_includes output, "After that deploy, delete the Postmark server"
    assert_not_includes output, "deleted custom hostname"
    assert_not_includes output, "deleted server"
    assert_not_includes output, "deleted domain"
  end

  test "phase 1 is idempotent when the Cap key was already deleted" do
    Current.org.update!(
      cap_site_key: "gone-site-key",
      cap_secret_key: "gone-secret",
      postmark_server_id: 9999,
      postmark_server_token: "gone-token")

    stub_request(:get, "https://cap.test/server/keys")
      .to_return(status: 200, body: [].to_json)
    out = StringIO.new

    remover = Tenant::Remover.new(
      "acme",
      confirm: "acme",
      out: out,
      cap_client: Cap::Client.new(api_url: "https://cap.test", api_key: "api-key"))
    remover.run

    Current.org.reload
    assert_nil Current.org.cap_site_key
    assert_equal "9999", Current.org.postmark_server_id
    assert_equal "gone-token", Current.org.postmark_server_token

    output = out.string
    assert_includes output, "Cap: site key gone-site-key not found (already deleted)"
    assert_includes output, "Postmark: delete server 9999 and domain acme.test manually at https://account.postmarkapp.com/servers"
  end

  test "notes that a shared Postmark domain should be kept" do
    Current.org.update!(postmark_server_id: 4242, postmark_server_token: "pm-token")
    out = StringIO.new

    with_env("APP_DOMAIN" => "acme.test") do
      Tenant::Remover.new("acme", confirm: "acme", out: out).print_postmark_manual_step
    end

    output = out.string
    assert_includes output, "Postmark: delete server 4242 manually at https://account.postmarkapp.com/servers"
    assert_includes output, "Postmark: domain acme.test is shared (keep it)"
    assert_not_includes output, "delete server 4242 and domain"
  end

  test "falls back to Cap key name lookup when local database is absent" do
    stub_request(:get, "https://cap.test/server/keys")
      .to_return(status: 200, body: [ { siteKey: "named-key", name: "acme" } ].to_json)
    cap_delete = stub_request(:delete, "https://cap.test/server/keys/named-key")
      .to_return(status: 200, body: { success: true }.to_json)

    out = StringIO.new
    remover = Tenant::Remover.new(
      "acme",
      confirm: "acme",
      out: out,
      cap_client: Cap::Client.new(api_url: "https://cap.test", api_key: "api-key"))

    remover.stub(:tenant_db_exists?, false) do
      remover.delete_cap_keys
    end

    assert_requested cap_delete
    assert_includes out.string, "local database not found"
    assert_includes out.string, "deleted site key named-key (acme)"
  end

  test "handles a tenant database with no organization row" do
    stub_request(:get, "https://cap.test/server/keys")
      .to_return(status: 200, body: [].to_json)

    out = StringIO.new
    remover = Tenant::Remover.new(
      "acme",
      confirm: "acme",
      out: out,
      cap_client: Cap::Client.new(api_url: "https://cap.test", api_key: "api-key"))

    Organization.stub(:first, nil) do
      remover.delete_cap_keys
      remover.print_postmark_manual_step
    end

    output = out.string
    assert_includes output, "Cap: no site key found for 'acme' (skipped)"
    assert_includes output, "Postmark: no server configured for 'acme' (skipped)"
    assert_includes output, "Postmark: delete domain acme.test manually at https://account.postmarkapp.com/servers"
  end

  test "refuses to clear object storage or litestream while tenant is in tenant.yml" do
    remover = Tenant::Remover.new("acme", confirm: "acme", out: StringIO.new)

    storage_error = assert_raises(RuntimeError) { remover.clear_object_storage }
    assert_includes storage_error.message, "config/tenant.yml"

    litestream_error = assert_raises(RuntimeError) { remover.clear_litestream_replica }
    assert_includes litestream_error.message, "litestream:config"
  end

  test "phase 2 dry-run lists storage and litestream objects without deleting" do
    storage_client = stub_s3_client(objects: %w[retired/blob1 retired/blob2])
    litestream_client = stub_s3_client(objects: %w[retired/0000/01.ltx retired/0009/01.ltx])
    out = StringIO.new

    remover = Tenant::Remover.new(
      "retired",
      out: out,
      storage_client: storage_client,
      litestream_client: litestream_client)
    remover.run

    assert_equal [ :list_objects_v2 ], storage_client.api_requests.map { |r| r[:operation_name] }
    assert_equal [ :list_objects_v2 ], litestream_client.api_requests.map { |r| r[:operation_name] }
    assert_equal(
      { bucket: "csa-admin-storage", prefix: "retired/" },
      storage_client.api_requests.first[:params])
    assert_equal(
      { bucket: "csa-admin-litestream", prefix: "retired/" },
      litestream_client.api_requests.first[:params])

    output = out.string
    assert_includes output, "Phase 2"
    assert_includes output, "dry-run Object storage: would delete 2 object(s) from 'csa-admin-storage/retired/'"
    assert_includes output, "dry-run Litestream: would delete 2 object(s) from 'csa-admin-litestream/retired/'"
    assert_includes output, "Re-run with CONFIRM=retired to execute Phase 2."
  end

  test "phase 2 confirmed deletes storage and litestream objects and is idempotent when empty" do
    storage_client = stub_s3_client(objects: %w[retired/blob1 retired/blob2])
    litestream_client = stub_s3_client(objects: %w[retired/0000/01.ltx])
    out = StringIO.new

    remover = Tenant::Remover.new(
      "retired",
      confirm: "retired",
      out: out,
      storage_client: storage_client,
      litestream_client: litestream_client)
    remover.run

    assert_equal %i[list_objects_v2 delete_objects],
      storage_client.api_requests.map { |r| r[:operation_name] }
    assert_equal %i[list_objects_v2 delete_objects],
      litestream_client.api_requests.map { |r| r[:operation_name] }
    assert_equal(
      [ { key: "retired/blob1" }, { key: "retired/blob2" } ],
      storage_client.api_requests.last[:params].dig(:delete, :objects))
    assert_equal(
      [ { key: "retired/0000/01.ltx" } ],
      litestream_client.api_requests.last[:params].dig(:delete, :objects))
    assert_includes out.string, "deleted 2 object(s) from 'csa-admin-storage/retired/'"
    assert_includes out.string, "deleted 1 object(s) from 'csa-admin-litestream/retired/'"

    empty_storage = stub_s3_client(objects: [])
    empty_litestream = stub_s3_client(objects: [])
    rerun_out = StringIO.new

    Tenant::Remover.new(
      "retired",
      confirm: "retired",
      out: rerun_out,
      storage_client: empty_storage,
      litestream_client: empty_litestream).run

    assert_equal [ :list_objects_v2 ], empty_storage.api_requests.map { |r| r[:operation_name] }
    assert_includes rerun_out.string, "no objects in 'csa-admin-storage/retired/' (skipped)"
    assert_includes rerun_out.string, "no objects in 'csa-admin-litestream/retired/' (skipped)"
  end

  test "phase 2 raises when S3 delete_objects reports partial errors" do
    storage_client = Aws::S3::Client.new(
      stub_responses: {
        list_objects_v2: { contents: [ { key: "retired/blob1" } ] },
        delete_objects: {
          errors: [ { key: "retired/blob1", code: "AccessDenied", message: "Denied" } ]
        }
      })

    remover = Tenant::Remover.new(
      "retired",
      confirm: "retired",
      out: StringIO.new,
      storage_client: storage_client)

    error = assert_raises(RuntimeError) { remover.clear_object_storage }
    assert_includes error.message, "retired/blob1 (AccessDenied: Denied)"
  end

  test "litestream S3 client normalizes bare endpoint and derives region" do
    fake_creds = ActiveSupport::OrderedOptions.new
    fake_creds.litestream = {
      endpoint: "s3.eu-central-003.backblazeb2.com",
      access_key_id: "key",
      secret_access_key: "secret"
    }

    remover = Tenant::Remover.new("retired", out: StringIO.new)
    Rails.application.stub(:credentials, -> { fake_creds }) do
      client = remover.send(:litestream_client)

      assert_equal "eu-central-003", client.config.region
      assert_equal "https://s3.eu-central-003.backblazeb2.com", client.config.endpoint.to_s
      assert client.config.force_path_style
      assert_equal "when_required", client.config.request_checksum_calculation
      assert_equal "when_required", client.config.response_checksum_validation
    end
  end

  private

  def stub_s3_client(objects:)
    Aws::S3::Client.new(
      stub_responses: {
        list_objects_v2: {
          contents: objects.map { |key| { key: key } },
          is_truncated: false
        },
        delete_objects: {
          deleted: objects.map { |key| { key: key } },
          errors: []
        }
      })
  end
end
