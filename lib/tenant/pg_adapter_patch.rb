# fix: strip schema from sequence name
module PostgreSqlAdapterPatch
  # Returns the sequence name for a table's primary key or some other specified key.
  def default_sequence_name(table_name, pk = "id") #:nodoc:#
    result = serial_sequence(table_name, pk)
    return nil unless result
    ActiveRecord::ConnectionAdapters::PostgreSQL::Utils.extract_schema_qualified_name(result).identifier
  rescue ActiveRecord::StatementInvalid
    PostgreSQL::Name.new(nil, "#{table_name}_#{pk}_seq").to_s
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include PostgreSqlAdapterPatch
end
