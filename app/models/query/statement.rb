# frozen_string_literal: true

module Query
  class Statement
    FORBIDDEN = %w[
      attach detach pragma vacuum insert update delete create drop
      alter load_extension
    ].freeze
    ALLOWED_HEAD = %w[select with].freeze

    def initialize(sql)
      @raw = sql.to_s
    end

    def stripped
      @stripped ||= scan(keep_strings: true).gsub(/;+\s*\z/, "").strip
    end

    def head
      stripped[/\A(\w+)/i, 1]&.downcase
    end

    def validate!
      raise Error, "empty query" if stripped.blank?
      raise Error, "multiple statements" if stacked?
      raise Error, "forbidden #{head}" unless ALLOWED_HEAD.include?(head)

      FORBIDDEN.each do |verb|
        raise Error, "forbidden #{verb}" if /\b#{Regexp.escape(verb)}\b/i.match?(bare)
      end
      raise Error, "forbidden replace" if /\breplace\s+into\b/i.match?(bare)

      self
    end

    private

    def stacked?
      bare.gsub(/;+\s*\z/, "").include?(";")
    end

    def bare
      @bare ||= scan(keep_strings: false).strip
    end

    def scan(keep_strings:)
      sql = @raw
      out = +""
      i = 0
      while i < sql.length
        two = sql[i, 2]
        ch = sql[i]
        if two == "--"
          i = sql.index("\n", i) || sql.length
        elsif two == "/*"
          close = sql.index("*/", i + 2)
          i = close ? close + 2 : sql.length
        elsif ch == "'"
          start = i
          i = skip_quoted(sql, i, "'")
          out << (keep_strings ? sql[start...i] : "''")
        elsif ch == '"' || ch == "`"
          start = i
          i = skip_quoted(sql, i, ch)
          out << (keep_strings ? sql[start...i] : "x")
        elsif ch == "["
          close = sql.index("]", i + 1)
          end_at = close ? close + 1 : sql.length
          out << (keep_strings ? sql[i...end_at] : "x")
          i = end_at
        else
          out << ch
          i += 1
        end
      end
      out
    end

    def skip_quoted(sql, i, quote)
      i += 1
      while i < sql.length
        if sql[i] == quote
          if sql[i + 1] == quote
            i += 2
          else
            return i + 1
          end
        else
          i += 1
        end
      end
      i
    end
  end
end
