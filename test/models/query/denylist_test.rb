# frozen_string_literal: true

require "test_helper"

class Query::DenylistTest < ActiveSupport::TestCase
  test "denied columns exist in schema.rb" do
    schema = Rails.root.join("db/schema.rb").read

    Query::Denylist::COLUMNS.each do |table, columns|
      block = schema[/create_table "#{Regexp.escape(table)}".*?^  end/m]
      assert block, "table #{table} missing from schema"
      columns.each do |column|
        assert_match(/t\.\w+ "#{Regexp.escape(column)}"/, block, "#{table}.#{column} missing from schema")
      end
    end
  end

  test "select star on organizations is denied" do
    error = assert_raises(Query::Error) { Query::Denylist.check!("SELECT * FROM organizations") }
    assert_match(/SELECT \* on organizations/, error.message)
    assert_match(/api_token/, error.message)
  end

  test "aliased star on organizations is denied" do
    error = assert_raises(Query::Error) { Query::Denylist.check!("SELECT o.* FROM organizations o") }
    assert_match(/SELECT \* on organizations/, error.message)
  end

  test "schema-qualified star is denied" do
    error = assert_raises(Query::Error) { Query::Denylist.check!("SELECT * FROM main.organizations") }
    assert_match(/SELECT \* on organizations/, error.message)
  end

  test "select id from organizations is allowed" do
    assert_nothing_raised { Query::Denylist.check!("SELECT id, name FROM organizations") }
  end

  test "count star is allowed" do
    assert_nothing_raised { Query::Denylist.check!("SELECT COUNT(*) FROM members") }
  end

  test "arithmetic star on organizations is allowed" do
    assert_nothing_raised { Query::Denylist.check!("SELECT price * 2 FROM organizations") }
  end

  test "join star onto organizations is denied" do
    error = assert_raises(Query::Error) {
      Query::Denylist.check!("SELECT * FROM members JOIN organizations")
    }
    assert_match(/SELECT \* on organizations/, error.message)
  end

  test "sqlite_ prefix is denied" do
    error = assert_raises(Query::Error) { Query::Denylist.check!("SELECT * FROM sqlite_master") }
    assert_match(/sqlite_/, error.message)
  end

  test "pragma_ table is denied" do
    error = assert_raises(Query::Error) { Query::Denylist.check!("SELECT * FROM pragma_table_info('organizations')") }
    assert_match(/pragma_/, error.message)
  end

  test "litestream internals are denied" do
    error = assert_raises(Query::Error) { Query::Denylist.check!("SELECT * FROM _litestream_seq") }
    assert_match(/_litestream_/, error.message)
  end

  test "result columns catch api_token" do
    error = assert_raises(Query::Error) { Query::Denylist.check_result!([ "id", "api_token" ]) }
    assert_match(/api_token/, error.message)
  end
end
