# frozen_string_literal: true

module Query
  class Denylist
    TABLE_PREFIXES = %w[sqlite_ pragma_ _litestream_].freeze

    def self.denied_table?(table)
      name = table.to_s.downcase
      TABLE_PREFIXES.any? { |prefix| name.start_with?(prefix) }
    end

    def self.check!(sql)
      text = sql.to_s.downcase
      TABLE_PREFIXES.each do |prefix|
        raise Error, "table #{prefix}* is denied" if text.match?(/\b#{Regexp.escape(prefix)}\w*/)
      end
    end
  end
end
