# frozen_string_literal: true

require "test_helper"

class Query::StatementTest < ActiveSupport::TestCase
  test "accepts select" do
    assert_equal "select", Query::Statement.new("SELECT id FROM members").tap(&:validate!).head
  end

  test "accepts with" do
    sql = "WITH x AS (SELECT 1 AS n) SELECT n FROM x"
    assert_equal "with", Query::Statement.new(sql).tap(&:validate!).head
  end

  test "rejects insert" do
    error = assert_raises(Query::Error) { Query::Statement.new("INSERT INTO members (name) VALUES ('x')").validate! }
    assert_match(/forbidden/, error.message)
  end

  test "rejects attach" do
    error = assert_raises(Query::Error) { Query::Statement.new("ATTACH 'other.sqlite3' AS o").validate! }
    assert_match(/forbidden attach/, error.message)
  end

  test "rejects pragma" do
    error = assert_raises(Query::Error) { Query::Statement.new("PRAGMA table_info(members)").validate! }
    assert_match(/forbidden pragma/, error.message)
  end

  test "rejects stacked statements" do
    error = assert_raises(Query::Error) { Query::Statement.new("SELECT 1; SELECT 2").validate! }
    assert_equal "multiple statements", error.message
  end

  test "rejects stacked after comments" do
    error = assert_raises(Query::Error) { Query::Statement.new("SELECT 1; -- ok\nATTACH 'x'").validate! }
    assert_equal "multiple statements", error.message
  end

  test "allows semicolon inside string" do
    assert Query::Statement.new("SELECT 'a;b' AS x").validate!
  end

  test "rejects empty" do
    error = assert_raises(Query::Error) { Query::Statement.new("  -- only comment").validate! }
    assert_equal "empty query", error.message
  end

  test "rejects explain as sql head" do
    error = assert_raises(Query::Error) { Query::Statement.new("EXPLAIN SELECT 1").validate! }
    assert_match(/forbidden explain/, error.message)
  end

  test "allows created_at column names" do
    assert Query::Statement.new("SELECT id, created_at, updated_at FROM members").validate!
  end

  test "allows trailing semicolon" do
    assert Query::Statement.new("SELECT 1;").validate!
  end

  test "allows replace function" do
    assert Query::Statement.new("SELECT REPLACE(email, '@', '') FROM members").validate!
  end

  test "rejects replace into" do
    error = assert_raises(Query::Error) { Query::Statement.new("REPLACE INTO members (name) VALUES ('x')").validate! }
    assert_match(/forbidden/, error.message)
  end

  test "allows verb inside a string" do
    assert Query::Statement.new("SELECT note FROM members WHERE note LIKE '%delete%'").validate!
  end

  test "strips comments inside strings as content not comments" do
    assert Query::Statement.new("SELECT '-- not a comment' AS x").validate!
  end
end
