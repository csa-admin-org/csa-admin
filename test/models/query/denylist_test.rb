# frozen_string_literal: true

require "test_helper"

class Query::DenylistTest < ActiveSupport::TestCase
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

  test "select star on organizations is allowed" do
    assert_nothing_raised { Query::Denylist.check!("SELECT * FROM organizations") }
  end
end
