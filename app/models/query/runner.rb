# frozen_string_literal: true

module Query
  class Runner
    DEFAULT_PER = 100
    MAX_PER = 500
    TIMEOUT_SECONDS = 5

    def self.sql(sql, page: 1, per: DEFAULT_PER)
      new(sql, page: page, per: per).run
    end

    def self.explain(sql)
      new(sql, page: 1, per: DEFAULT_PER).explain
    end

    def self.schema(table = nil)
      connection = ActiveRecord::Base.lease_connection
      if table
        format_table_detail(connection, table)
      else
        format_table_list(connection)
      end
    end

    def self.models
      Rails.application.eager_load!

      ActiveRecord::Base.descendants
        .reject(&:abstract_class?)
        .select { |model| model.table_name.present? && !Denylist.denied_table?(model.table_name) }
        .sort_by(&:name)
        .map { |model|
          {
            model: model.name,
            table_name: model.table_name,
            associations: format_associations(model)
          }
        }
    end

    def initialize(sql, page:, per:)
      @statement = Statement.new(sql).validate!
      Denylist.check!(@statement.stripped)
      @page = [ page.to_i, 1 ].max
      n = per.to_i
      n = DEFAULT_PER if n < 1
      @per = [ n, MAX_PER ].min
    end

    def run
      execute(paginated_sql)
    end

    def explain
      execute("EXPLAIN QUERY PLAN #{@statement.stripped}", paginate: false)
    end

    private

    def paginated_sql
      sql = @statement.stripped
      offset = (@page - 1) * @per
      "SELECT * FROM (#{sql}) AS q LIMIT #{@per + 1} OFFSET #{offset}"
    end

    def execute(sql, paginate: true)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = with_readonly { select_all(sql) }
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1)

      Denylist.check_result!(result.columns)
      rows = result.rows
      truncated = paginate && rows.length > @per
      rows = rows.first(@per) if paginate

      format_result(
        columns: result.columns,
        rows: rows,
        sql: sql,
        elapsed_ms: elapsed_ms,
        truncated: truncated)
    rescue ActiveRecord::ReadOnlyError
      raise Error, "write query attempted while in readonly mode"
    rescue ActiveRecord::StatementInvalid => e
      raise Error, "query_timeout" if e.cause.is_a?(SQLite3::InterruptException)
      raise Error, e.cause&.message.presence || e.message
    end

    def select_all(sql)
      connection = ActiveRecord::Base.lease_connection
      with_timeout(connection) { connection.select_all(sql) }
    end

    def with_readonly
      connection = ActiveRecord::Base.lease_connection
      connection.execute("PRAGMA query_only = ON")
      ActiveRecord::Base.while_preventing_writes { yield }
    ensure
      connection&.execute("PRAGMA query_only = OFF")
    end

    def with_timeout(connection)
      raw = connection.raw_connection
      raw.statement_timeout = TIMEOUT_SECONDS * 1000
      yield
    rescue SQLite3::InterruptException
      raise Error, "query_timeout"
    ensure
      raw&.statement_timeout = 0
    end

    def format_result(columns:, rows:, sql:, elapsed_ms: 0, truncated: false)
      {
        columns: columns,
        rows: rows,
        meta: {
          row_count: rows.length,
          query_time_ms: elapsed_ms,
          page: @page,
          per_page: @per,
          has_more: truncated,
          sql: sql
        }
      }
    end

    def self.format_table_list(connection)
      tables = connection.tables.sort.reject { |table| Denylist.denied_table?(table) }
      {
        columns: [ "table_name" ],
        rows: tables.map { |table| [ table ] },
        meta: {
          row_count: tables.length,
          query_time_ms: 0,
          page: 1,
          per_page: tables.length,
          has_more: false,
          sql: ""
        }
      }
    end

    def self.format_table_detail(connection, table)
      raise Error, "not_found" if Denylist.denied_table?(table)
      raise Error, "not_found" unless connection.table_exists?(table)

      denied = Denylist.denied_columns_for(table)
      model = model_for_table(table)

      {
        table: table,
        columns: connection.columns(table).filter_map { |col|
          next if denied.include?(col.name)

          { name: col.name, type: col.sql_type, null: col.null, default: col.default }
        },
        indexes: connection.indexes(table).map { |idx|
          { name: idx.name, columns: idx.columns, unique: idx.unique }
        },
        enums: model&.defined_enums.presence,
        associations: format_associations(model)
      }.compact
    end

    def self.model_for_table(table)
      Rails.application.eager_load!

      ActiveRecord::Base.descendants.find { |klass|
        !klass.abstract_class? && klass.table_name == table
      }
    end

    def self.format_associations(model)
      return unless model

      model.reflect_on_all_associations.filter_map do |assoc|
        next if assoc.polymorphic?

        table = begin
          assoc.klass.table_name
        rescue ArgumentError, NoMethodError
          next
        end
        next if Denylist.denied_table?(table)

        hash = {
          type: assoc.macro,
          name: assoc.name,
          class_name: assoc.class_name
        }
        hash[:foreign_key] = assoc.foreign_key if assoc.respond_to?(:foreign_key)
        hash[:through] = assoc.through_reflection.name if assoc.through_reflection?
        hash
      end
    end
    private_class_method :format_table_list, :format_table_detail, :model_for_table, :format_associations
  end
end
