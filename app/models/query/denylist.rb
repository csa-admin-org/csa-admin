# frozen_string_literal: true

module Query
  class Denylist
    TABLE_PREFIXES = %w[sqlite_ pragma_ _litestream_].freeze

    COLUMNS = {
      "organizations" => %w[api_token icalendar_auth_token]
    }.freeze

    def self.denied_table?(table)
      name = table.to_s.downcase
      TABLE_PREFIXES.any? { |prefix| name.start_with?(prefix) }
    end

    def self.denied_columns_for(table)
      COLUMNS[table.to_s.downcase] || []
    end

    def self.check!(sql)
      text = sql.to_s.downcase
      check_tables!(text)
      check_secret_tables!(text)
    end

    def self.check_result!(columns)
      names = Array(columns).map { |column| column.to_s.downcase }
      hit = COLUMNS.values.flatten.uniq.select { |column| names.include?(column) }
      return if hit.empty?

      raise Error, "column #{hit.join(", ")} is denied"
    end

    def self.check_tables!(text)
      TABLE_PREFIXES.each do |prefix|
        raise Error, "table #{prefix}* is denied" if text.match?(/\b#{Regexp.escape(prefix)}\w*/)
      end
    end
    private_class_method :check_tables!

    def self.check_secret_tables!(text)
      COLUMNS.each do |table, columns|
        next unless identifier?(text, table)

        if star?(text)
          raise Error, "SELECT * on #{table} is denied (#{columns.join(", ")})"
        end

        hit = columns.select { |column| identifier?(text, column) }
        next if hit.empty?

        raise Error, "column #{hit.map { |column| "#{table}.#{column}" }.join(", ")} is denied"
      end
    end
    private_class_method :check_secret_tables!

    def self.identifier?(text, word)
      text.match?(/\b#{Regexp.escape(word)}\b/)
    end
    private_class_method :identifier?

    def self.star?(text)
      cleaned = text.gsub(/\b(?:count|sum|avg|min|max|group_concat|total)\s*\(\s*\*\s*\)/i, "")
      cleaned.match?(/\.\s*\*/) ||
        cleaned.match?(/\bselect\b[\s\S]*?(?:^|[,\s])\*(?:\s*,|\s+from\b)/i)
    end
    private_class_method :star?
  end
end
