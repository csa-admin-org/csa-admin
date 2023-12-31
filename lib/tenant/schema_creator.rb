module Tenant
  class SchemaCreator
    PSQL_DUMP_IGNORED_STATEMENTS = [
      /SET search_path/i,                           # overridden later
      /SET lock_timeout/i,                          # new in postgresql 9.3
      /SET row_security/i,                          # new in postgresql 9.5
      /SET idle_in_transaction_session_timeout/i,   # new in postgresql 9.6
      /SET default_table_access_method/i,           # new in postgresql 12
      /CREATE SCHEMA public/i,
      /COMMENT ON SCHEMA public/i
    ].freeze

    def initialize(connection, connection_config_hash)
      @connection = connection
      @config = connection_config_hash
    end

    def run
      preserving_search_path do
        clone_pg_schema
        copy_schema_migrations
      end
    end

    private

    def preserving_search_path
      search_path = @connection.execute("show search_path").first["search_path"]
      yield
      @connection.execute("set search_path = #{search_path}")
    end

    def clone_pg_schema
      pg_schema_sql = patch_search_path(pg_dump_schema)
      @connection.execute(pg_schema_sql)
    end

    def copy_schema_migrations
      pg_migrations_data = patch_search_path(pg_dump_schema_migrations_data)
      @connection.execute(pg_migrations_data)
    end

    def pg_dump_schema
      with_pg_env { `pg_dump -s -x -O -n #{Tenant.default} #{@config[:database]}` }
    end

    def pg_dump_schema_migrations_data
      with_pg_env { `pg_dump -a --inserts -t #{Tenant.default}.schema_migrations -t #{Tenant.default}.ar_internal_metadata #{@config[:database]}` }
    end

    def with_pg_env
      pghost = ENV["PGHOST"]
      pgport = ENV["PGPORT"]
      pguser = ENV["PGUSER"]
      pgpassword = ENV["PGPASSWORD"]

      ENV["PGHOST"] = @config[:host] if @config[:host]
      ENV["PGPORT"] = @config[:port].to_s if @config[:port]
      ENV["PGUSER"] = @config[:username].to_s if @config[:username]
      ENV["PGPASSWORD"] = @config[:password].to_s if @config[:password]

      yield
    ensure
      ENV["PGHOST"] = pghost
      ENV["PGPORT"] = pgport
      ENV["PGUSER"] = pguser
      ENV["PGPASSWORD"] = pgpassword
    end

    def patch_search_path(sql)
      search_path = "SET search_path = \"#{Tenant.current}\", #{Tenant.default};"

      swap_schema_qualifier(sql)
        .split("\n")
        .select { |line| check_input_against_regexps(line, PSQL_DUMP_IGNORED_STATEMENTS).empty? }
        .prepend(search_path)
        .join("\n")
    end

    def swap_schema_qualifier(sql)
      sql.gsub(/#{Tenant.default}\.\S*/) do |match|
        match.gsub("#{Tenant.default}.", %("#{Tenant.current}".))
      end
    end

    def check_input_against_regexps(input, regexps)
      regexps.select { |c| input.match c }
    end
  end
end
