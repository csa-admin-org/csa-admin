# frozen_string_literal: true

require "test_helper"

class Query::RunnerTest < ActiveSupport::TestCase
  test "selects rows with envelope" do
    result = Query::Runner.sql("SELECT id, name FROM members WHERE id = #{members(:john).id}")

    assert_equal [ "id", "name" ], result[:columns]
    assert_equal 1, result[:rows].length
    assert_equal members(:john).id, result[:rows].first.first
    refute result[:meta][:has_more]
    assert_match(/LIMIT 101/, result[:meta][:sql])
  end

  test "paginates with has_more" do
    result = Query::Runner.sql("SELECT id FROM members ORDER BY id", per: 1)

    assert_equal 1, result[:rows].length
    assert result[:meta][:has_more]
    assert_equal 1, result[:meta][:per_page]
  end

  test "caps per at 500" do
    result = Query::Runner.sql("SELECT id FROM members", per: 999)

    assert_equal 500, result[:meta][:per_page]
    assert_match(/LIMIT 501/, result[:meta][:sql])
  end

  test "rejects writes" do
    error = assert_raises(Query::Error) { Query::Runner.sql("INSERT INTO members (name) VALUES ('x')") }
    assert_match(/forbidden/, error.message)
  end

  test "explain query plan returns plan rows" do
    result = Query::Runner.explain("SELECT id FROM members WHERE id = 1")

    assert_includes result[:columns], "detail"
    assert result[:rows].any?
    refute_includes result[:columns], "opcode"
  end

  test "schema omits sqlite internals and secret columns" do
    list = Query::Runner.schema
    names = list[:rows].flatten
    refute names.any? { |name| name.start_with?("sqlite_", "_litestream_") }
    assert_includes names, "sessions"

    org = Query::Runner.schema("organizations")
    column_names = org[:columns].map { |col| col[:name] }
    refute_includes column_names, "api_token"
    assert_includes column_names, "name"
  end

  test "schema of sqlite_master is not_found" do
    error = assert_raises(Query::Error) { Query::Runner.schema("sqlite_master") }
    assert_equal "not_found", error.message
  end

  test "models include sessions" do
    names = Query::Runner.models.map { |row| row[:table_name] }
    assert_includes names, "sessions"
    assert_includes names, "members"
  end
end
