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

  test "organizations get query params" do
    client = FakeClient.new
    Query::CLI.new(
      [ "/organizations", "--attributes", "features", "--absences_included_mode", "provisional_absence" ],
      client: client,
      out: StringIO.new).run

    assert_equal [ [ "/organizations", {
      "attributes" => "features",
      "absences_included_mode" => "provisional_absence"
    } ] ], client.gets
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

  test "tickets search posts" do
    client = FakeClient.new
    Query::CLI.new(
      [ "/tickets/search", "--q", "absences", "--per", "20" ],
      client: client,
      out: StringIO.new).run

    assert_equal [ [ "/tickets/search", { "q" => "absences", "per" => "20" } ] ], client.posts
  end

  test "tickets search posts tenant filter" do
    client = FakeClient.new
    Query::CLI.new(
      [ "/tickets/search", "--q", "EBICS", "--tenant", "lamule,ortie" ],
      client: client,
      out: StringIO.new).run

    assert_equal [
      [ "/tickets/search", { "q" => "EBICS", "tenant" => "lamule,ortie" } ]
    ], client.posts
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

  test "-h prints the configured host without a client" do
    out = StringIO.new
    with_env("CSA_ADMIN_API_URL" => "https://query.csa-admin.test", "CSA_ADMIN_API_TOKEN" => nil) do
      Query::CLI.new([ "-h" ], out: out).run
    end

    assert_includes out.string, "https://query.csa-admin.test"
    assert_includes out.string, "Auth: CSA_ADMIN_API_TOKEN (missing)"
    assert_includes out.string, "bin/query /organizations"
    assert_includes out.string, "bin/query /tickets/search"
    assert_includes out.string, "bin/query /lamule/sql"
  end

  test "no args prints help" do
    out = StringIO.new
    with_env("CSA_ADMIN_API_URL" => Query::Client::DEFAULT_URL) do
      Query::CLI.new([], out: out).run
    end

    assert_includes out.string, Query::Client::DEFAULT_URL
    assert_includes out.string, "Fleet"
  end
end
