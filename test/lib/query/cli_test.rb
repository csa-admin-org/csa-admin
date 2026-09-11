# frozen_string_literal: true

require "test_helper"
require "query/cli"

class Query::CLITest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :gets, :posts

    def initialize(body = { "ok" => true })
      @body = body
      @gets = []
      @posts = []
    end

    def get(path, params = {})
      @gets << [ path, params ]
      @body
    end

    def post(path, params = {})
      @posts << [ path, params ]
      @body
    end

    def download(path)
      @gets << [ path, {} ]
      "%PDF-1.4"
    end
  end

  test "catalog hits GET /" do
    client = FakeClient.new("routes" => [])
    out = StringIO.new

    Query::CLI.new([ "/" ], client: client, out: out).run

    assert_equal [ [ "/", {} ] ], client.gets
    assert_includes out.string, "routes"
  end

  test "sql posts body" do
    client = FakeClient.new
    Query::CLI.new(
      [ "/lamule/sql", "--sql", "SELECT 1" ],
      client: client,
      out: StringIO.new).run

    assert_equal [ [ "/lamule/sql", { "sql" => "SELECT 1" } ] ], client.posts
  end

  test "explain posts" do
    client = FakeClient.new
    Query::CLI.new(
      [ "/lamule/explain", "--sql", "SELECT 1" ],
      client: client,
      out: StringIO.new).run

    assert_equal [ [ "/lamule/explain", { "sql" => "SELECT 1" } ] ], client.posts
  end

  test "blob writes raw bytes" do
    client = FakeClient.new
    out = StringIO.new

    Query::CLI.new([ "/lamule/blobs/42" ], client: client, out: out).run

    assert_equal [ [ "/lamule/blobs/42", {} ] ], client.gets
    assert_equal "%PDF-1.4", out.string
  end

  test "path is required" do
    error = assert_raises(Query::CLI::Error) {
      Query::CLI.new([ "schema" ], client: FakeClient.new, out: StringIO.new).run
    }
    assert_equal Query::CLI::USAGE, error.message
  end
end
