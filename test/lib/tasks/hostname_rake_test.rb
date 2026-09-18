# frozen_string_literal: true

require "test_helper"
require "rake"

class HostnameRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("hostname:cloudflare:check")
  end

  test "prints TXT records from ssl validation_records" do
    ssl = {
      status: "pending_validation",
      validation_records: [
        {
          txt_name: "_acme-challenge.admin.acme.test",
          txt_value: "token-one"
        },
        {
          txt_name: "_acme-challenge.members.acme.test",
          txt_value: "token-two"
        }
      ]
    }

    out, = capture_io { print_ssl_txt_records(ssl) }

    assert_includes out, "TXT NAME:  _acme-challenge.admin"
    assert_includes out, "TXT VALUE: token-one"
    assert_includes out, "TXT NAME:  _acme-challenge.members"
    assert_includes out, "TXT VALUE: token-two"
  end

  test "prints both TXT values under one name for dual-CA DCV" do
    ssl = {
      validation_records: [
        { txt_name: "_acme-challenge.admin.acme.test", txt_value: "token-one" },
        { txt_name: "_acme-challenge.admin.acme.test", txt_value: "token-two" }
      ]
    }

    out, = capture_io { print_ssl_txt_records(ssl) }

    assert_includes out, "TXT NAME:  _acme-challenge.admin"
    assert_includes out, "TXT VALUE: token-one"
    assert_includes out, "TXT VALUE: token-two"
    assert_equal 1, out.scan("TXT NAME:").size
  end

  test "prints TXT records from legacy ssl txt_name fields" do
    ssl = {
      status: "pending_validation",
      txt_name: "_acme-challenge.admin.acme.test",
      txt_value: "legacy-token"
    }

    out, = capture_io { print_ssl_txt_records(ssl) }

    assert_includes out, "TXT NAME:  _acme-challenge.admin"
    assert_includes out, "TXT VALUE: legacy-token"
  end

  test "does not crash when pending validation has no TXT records yet" do
    out, = capture_io { print_ssl_txt_records(status: "pending_validation") }

    assert_includes out, "TXT records not yet available"
  end

  test "prints success when hostname and SSL are active" do
    out, = capture_io { print_custom_hostname_status(custom_hostname_stub) }

    assert_includes out, "✅"
    assert_not_includes out, "Hostname Status"
  end

  test "prints pending SSL TXT records when hostname is active" do
    out, = capture_io {
      print_custom_hostname_status(custom_hostname_stub(
        ssl_status: "pending_validation",
        validation_records: [
          { txt_name: "_acme-challenge.admin.acme.test", txt_value: "token-one" }
        ]))
    }

    assert_includes out, "❌"
    assert_includes out, "Hostname Status: active"
    assert_includes out, "SSL Status:      pending_validation"
    assert_includes out, "TXT NAME:  _acme-challenge.admin"
    assert_includes out, "TXT VALUE: token-one"
  end

  test "prints default min TLS when hostname is active on TLS 1.0" do
    out, = capture_io {
      print_custom_hostname_status(custom_hostname_stub(min_tls_version: nil))
    }

    assert_includes out, "❌"
    assert_includes out, "Min TLS:         1.0 (default)"
  end

  test "creates custom hostnames with TXT DCV and TLS 1.2" do
    assert_equal(
      { method: "txt", type: "dv", settings: { min_tls_version: "1.2" } },
      custom_hostname_ssl)
  end

  test "treats TLS 1.2 as the required min version" do
    assert min_tls_1_2?(custom_hostname_stub)
    assert_not min_tls_1_2?(custom_hostname_stub(min_tls_version: "1.0"))
    assert_not min_tls_1_2?(custom_hostname_stub(min_tls_version: nil))
  end

  test "only patches min TLS on active SSL that is still on 1.0" do
    assert patch_min_tls?(custom_hostname_stub(min_tls_version: nil))
    assert_not patch_min_tls?(custom_hostname_stub)
    assert_not patch_min_tls?(custom_hostname_stub(
      ssl_status: "pending_validation",
      min_tls_version: nil))
  end

  test "explains why min TLS is not patched" do
    assert_equal "already 1.2", tls_skip_reason(custom_hostname_stub)
    assert_equal "SSL pending_validation",
      tls_skip_reason(custom_hostname_stub(
        ssl_status: "pending_validation",
        min_tls_version: nil))
  end

  test "info row includes CA and min TLS for an existing hostname" do
    row = custom_hostname_info_row(
      "pluk",
      "admin.plukcsa.nl",
      custom_hostname_stub(method: "txt", certificate_authority: "ssl_com"))

    assert_equal [
      "pluk",
      "admin.plukcsa.nl",
      "active",
      "active",
      "txt",
      "ssl_com",
      "1.2"
    ], row
  end

  test "info row marks missing custom hostnames" do
    assert_equal(
      [ "pluk", "admin.plukcsa.nl", "missing", "-", "-", "-", "-" ],
      custom_hostname_info_row("pluk", "admin.plukcsa.nl", nil))
  end

  test "info row defaults missing CA and min TLS" do
    row = custom_hostname_info_row(
      "ragedevert",
      "admin.ragedevert.ch",
      custom_hostname_stub(
        method: "http",
        certificate_authority: nil,
        min_tls_version: nil))

    assert_equal "default", row[5]
    assert_equal "1.0 (default)", row[6]
  end

  private

  def custom_hostname_stub(
    status: "active",
    ssl_status: "active",
    method: nil,
    certificate_authority: nil,
    min_tls_version: "1.2",
    validation_records: nil)
    ssl = Cloudflare::CustomHostname::SSLAttribute.new({
      status: ssl_status,
      method: method,
      certificate_authority: certificate_authority,
      settings: { min_tls_version: min_tls_version }.compact,
      validation_records: validation_records
    }.compact)
    Object.new.tap do |hostname|
      hostname.define_singleton_method(:result) { { status: status } }
      hostname.define_singleton_method(:ssl) { ssl }
    end
  end
end
