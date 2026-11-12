# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "stringio"
require "zlib"

class AnonymizedDumpRestoreTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
  end

  teardown do
    FileUtils.rm_rf(@root)
  end

  test "copies a local sqlite file into development storage" do
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "acme.sqlite3"), "sqlite-bytes")
      with_env("ANONYMIZED_DUMPS_LOCAL_DIR" => dir) do
        path = AnonymizedDump::Restore.call([ "acme" ], root: @root).first

        assert_equal @root.join("development_acme.sqlite3"), path
        assert_equal "sqlite-bytes", File.binread(path)
      end
    end
  end

  test "downloads the latest gzip with a read-only client" do
    bytes = gzip("sqlite-bytes")
    calls = []
    client = Object.new
    client.define_singleton_method(:get_object) do |**kwargs|
      calls << kwargs
      Struct.new(:body).new(StringIO.new(bytes))
    end

    with_env(
      "ANONYMIZED_DUMPS_BUCKET" => "anonymized-test",
      "ANONYMIZED_DUMPS_ENDPOINT" => "https://s3.example.test",
      "ANONYMIZED_DUMPS_ACCESS_KEY_ID" => "key",
      "ANONYMIZED_DUMPS_SECRET_ACCESS_KEY" => "secret",
      "ANONYMIZED_DUMPS_LOCAL_DIR" => nil) do
      path = AnonymizedDump::Restore.call([ "acme" ], root: @root, client: client).first

      assert_equal "sqlite-bytes", File.binread(path)
      assert_equal(
        { bucket: "anonymized-test", key: "tenants/acme/latest.sqlite3.gz" },
        calls.first)
    end
  end

  test "refuses demo tenants and unknown names" do
    demo = assert_raises(AnonymizedDump::Error) {
      AnonymizedDump::Restore.call([ "demo-en" ], root: @root)
    }
    unknown = assert_raises(AnonymizedDump::Error) {
      AnonymizedDump::Restore.call([ "nope" ], root: @root)
    }

    assert_match(/demo/, demo.message)
    assert_match(/unknown tenant/, unknown.message)
  end

  test "refuses to run in production" do
    with_rails_env("production") do
      error = assert_raises(AnonymizedDump::Error) {
        AnonymizedDump::Restore.call([ "acme" ], root: @root)
      }
      assert_match(/production/, error.message)
    end
  end

  test "names the missing read-only credentials" do
    with_env(
      "ANONYMIZED_DUMPS_LOCAL_DIR" => nil,
      "ANONYMIZED_DUMPS_BUCKET" => nil,
      "ANONYMIZED_DUMPS_ENDPOINT" => nil,
      "ANONYMIZED_DUMPS_ACCESS_KEY_ID" => nil,
      "ANONYMIZED_DUMPS_SECRET_ACCESS_KEY" => nil) do
      error = assert_raises(AnonymizedDump::Error) {
        AnonymizedDump::Restore.call([ "acme" ], root: @root)
      }
      assert_match(/ANONYMIZED_DUMPS_ACCESS_KEY_ID/, error.message)
    end
  end

  private

  def gzip(contents)
    io = StringIO.new
    Zlib::GzipWriter.wrap(io) { |writer| writer.write(contents) }
    io.string
  end
end
