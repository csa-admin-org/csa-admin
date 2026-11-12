# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "zlib"
require "stringio"

class AnonymizedDumpPublisherTest < ActiveSupport::TestCase
  test "object keys are dated plus latest" do
    keys = AnonymizedDump::Publisher.object_keys("ragedevert", date: Date.new(2026, 11, 12))

    assert_equal "tenants/ragedevert/2026-11-12.sqlite3.gz", keys[:dated]
    assert_equal "tenants/ragedevert/latest.sqlite3.gz", keys[:latest]
    assert_equal 30, AnonymizedDump::Publisher.retention_days
  end

  test "compress round trips" do
    Dir.mktmpdir do |dir|
      source = File.join(dir, "db.sqlite3")
      dest = File.join(dir, "db.sqlite3.gz")
      File.binwrite(source, "sqlite-bytes")

      AnonymizedDump::Publisher.compress(source, dest)

      assert_equal "sqlite-bytes", Zlib::GzipReader.open(dest, &:read)
    end
  end

  test "upload is not wired" do
    error = assert_raises(NotImplementedError) {
      AnonymizedDump::Publisher.upload!(tenant: "ragedevert", gzip_path: "/tmp/none.sqlite3.gz")
    }

    assert_match(/ANONYMIZED_DUMPS_/, error.message)
    assert_match(%r{tenants/ragedevert/latest.sqlite3.gz}, error.message)
  end

  test "pipeline stops before anonymizing when replica restore is unwired" do
    email = members(:john).emails

    assert_raises(NotImplementedError) { AnonymizedDump::Pipeline.run!("acme") }

    assert_equal email, members(:john).reload.emails
  end

  test "litestream restore is not wired and names the output path" do
    error = assert_raises(NotImplementedError) {
      AnonymizedDump::LitestreamRestore.call(tenant: "ragedevert", output: "/tmp/ragedevert.sqlite3")
    }

    assert_match(/litestream restore -o/, error.message)
    assert_match(%r{/tmp/ragedevert.sqlite3}, error.message)
  end
end
