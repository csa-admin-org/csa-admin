# frozen_string_literal: true

module Style
  module Tools
    Phase = Data.define(:mode, :tools)

    def self.all
      [ Locales, Syntax, Rubocop, HerbLint, HerbFormat, Oxfmt, Oxlint, Prettier, Stylelint ]
    end

    def self.phases(mode)
      mode == :check ? [ Phase.new(mode: :check, tools: all) ] : fix_phases
    end

    def self.fix_phases
      [
        Phase.new(mode: :fix, tools: [ Locales, HerbFormat, Oxfmt, Prettier ]),
        Phase.new(mode: :fix, tools: [ Rubocop, Oxlint, Stylelint ]),
        Phase.new(mode: :check, tools: [ Syntax, HerbLint ])
      ]
    end

    class Locales < Tool
      def command(mode)
        return if skip?(select(patterns: %w[config/locales/**/*.{yml,yaml}], prefixes: %w[config/locales]))

        [ "bin/locales", check?(mode) ? "check" : "format" ]
      end
    end

    # Prism-backed `ruby -cW2` via bin/syntax. Check-only (no auto-fix).
    class Syntax < Tool
      # Avoid Gemfile.* / Rakefile.* — those match lockfiles and non-Ruby variants.
      PATTERNS = [
        "**/*.{rb,rake,gemspec}",
        "**/Gemfile",
        "**/Rakefile"
      ].freeze

      def command(mode)
        return unless check?(mode)

        selected = select(patterns: PATTERNS)
        return if skip?(selected)

        [ "bin/syntax", *selected ]
      end
    end

    class Rubocop < Tool
      PATTERNS = [
        "**/*.{rb,rake,gemspec,erb}",
        "**/Gemfile",
        "**/Gemfile.*",
        "**/Rakefile",
        "**/Rakefile.*"
      ].freeze

      def command(mode)
        selected = select(patterns: PATTERNS)
        return if skip?(selected)

        [ "bin/rubocop", *flags(mode), *targets(selected) ]
      end

      private

      def flags(mode)
        check?(mode) ? %w[--parallel --format simple] : %w[--parallel --autocorrect-all --format quiet]
      end

      def targets(selected)
        selected.empty? ? [] : [ "--only-recognized-file-types", *selected ]
      end
    end

    class HerbLint < Tool
      def command(mode)
        return unless check?(mode)

        selected = select(patterns: HerbFormat::PATTERNS)
        return if skip?(selected)

        [ "bin/herb", "lint", *scope(selected), *github_flag ]
      end

      private

      def scope(selected)
        selected.empty? ? [ "." ] : selected
      end

      def github_flag
        ENV["GITHUB_ACTIONS"] ? [ "--github" ] : []
      end
    end

    class HerbFormat < Tool
      PATTERNS = [
        "**/*.herb",
        "**/*.html.erb",
        "**/*.html.herb",
        "**/*.html",
        "**/*.html+*.erb",
        "**/*.rhtml",
        "**/*.turbo_stream.erb"
      ].freeze

      def command(mode)
        selected = select(patterns: PATTERNS)
        return if skip?(selected)

        [ "bin/herb", "format", *scope(selected), *suffix(mode) ]
      end

      private

      def scope(selected)
        selected.empty? ? [ "." ] : selected
      end

      def suffix(mode)
        check?(mode) ? [ "--check" ] : []
      end
    end

    class Oxfmt < Tool
      def command(mode)
        selected = select(prefixes: %w[app/javascript])
        return if skip?(selected)

        [ "bin/oxfmt", *scope(selected), *suffix(mode) ]
      end

      private

      def scope(selected)
        selected.empty? ? [ "app/javascript" ] : selected
      end

      def suffix(mode)
        check?(mode) ? [ "--check" ] : []
      end
    end

    class Oxlint < Tool
      def command(mode)
        selected = select(prefixes: %w[app/javascript])
        return if skip?(selected)

        [ "bin/oxlint", *scope(selected), *suffix(mode) ]
      end

      private

      def scope(selected)
        selected.empty? ? [ "app/javascript" ] : selected
      end

      def suffix(mode)
        check?(mode) ? [] : [ "--fix" ]
      end
    end

    class Prettier < Tool
      def command(mode)
        selected = select(prefixes: %w[app/assets/tailwind])
        return if skip?(selected)

        [ "bin/prettier", *scope(selected), flag(mode), "--cache", "--log-level", "warn" ]
      end

      private

      def scope(selected)
        selected.empty? ? [ "app/assets/tailwind/**/*.css" ] : selected
      end

      def flag(mode)
        check?(mode) ? "--check" : "--write"
      end
    end

    class Stylelint < Tool
      def command(mode)
        selected = select(prefixes: %w[app/assets/tailwind])
        return if skip?(selected)

        [ "bin/stylelint", *scope(selected), *suffix(mode) ]
      end

      private

      def scope(selected)
        selected.empty? ? [ "app/assets/tailwind/**/*.css" ] : selected
      end

      def suffix(mode)
        check?(mode) ? [] : [ "--fix" ]
      end
    end
  end
end
