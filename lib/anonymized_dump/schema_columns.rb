# frozen_string_literal: true

module AnonymizedDump
  # Columns declared in db/schema.rb. The fail-closed check compares this
  # inventory to config/anonymized_dump.yml, so a migration that adds a
  # column fails CI until someone classifies it.
  class SchemaColumns
    COLUMN_TYPES = %w[
      string text integer bigint decimal float boolean date datetime json virtual binary
    ].freeze
    COLUMN_NAME = /\A[a-z_][a-z0-9_]*\z/

    Column = Struct.new(:name, :type, :null, :virtual, keyword_init: true)
    Table = Struct.new(:name, :columns, keyword_init: true)

    def self.parse(path = Rails.root.join("db/schema.rb"))
      new(File.read(path))
    end

    def initialize(schema)
      @schema = schema
    end

    def tables
      @tables ||= parse_tables
    end

    def names
      tables.to_h { |table| [ table.name, table.columns.map(&:name) ] }
    end

    def [](table_name)
      tables.find { |table| table.name == table_name }
    end

    private

    def parse_tables
      parsed = []
      current = nil
      columns = []

      @schema.each_line do |line|
        if (match = line.match(/^  create_table "([^"]+)"(.*) do \|t\|/))
          current = match[1]
          columns = []
          unless match[2].include?("id: false")
            columns << Column.new(name: "id", type: "integer", null: false, virtual: false)
          end
        elsif (match = line.match(/create_virtual_table "([^"]+)", "[^"]+", \[(.*)\]/))
          parsed << Table.new(name: match[1], columns: virtual_columns(match[2]))
        elsif current && (match = line.match(/^    t\.(\w+) "([^"]+)"(.*)$/))
          type, name, rest = match.captures
          next unless COLUMN_TYPES.include?(type)
          next unless name.match?(COLUMN_NAME)

          columns << Column.new(
            name: name,
            type: type == "virtual" ? (rest[/type: :(\w+)/, 1] || "text") : type,
            null: !rest.include?("null: false"),
            virtual: type == "virtual")
        elsif current && line.match?(/^  end\b/)
          parsed << Table.new(name: current, columns: columns)
          current = nil
          columns = []
        end
      end

      parsed
    end

    def virtual_columns(body)
      body.scan(/"([^"]+)"/).filter_map do |(raw)|
        name = raw.split.first
        next if name.empty? || name == "tokenize" || name.include?("=")

        Column.new(name: name, type: "text", null: true, virtual: false)
      end
    end
  end
end
