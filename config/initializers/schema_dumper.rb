# frozen_string_literal: true

# Ignore internal tables when dumping schema.
# - Litestream tables are created for replication tracking
# - SQLite stat tables are created by ANALYZE for query optimization
Rails.application.config.active_record.schema_ignored_tables = %w[
  _litestream_lock
  _litestream_seq
  sqlite_stat1
  sqlite_stat4
]
