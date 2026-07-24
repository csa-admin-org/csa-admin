# frozen_string_literal: true

module Style
  module Tools
    Phase = Data.define(:mode, :tools)

    def self.all
      [ Locales, Syntax, Rubocop, Actionlint, HerbLint, HerbFormat, Oxfmt, Oxlint, Prettier, Stylelint ]
    end

    def self.phases(mode)
      mode == :check ? [ Phase.new(mode: :check, tools: all) ] : fix_phases
    end

    def self.fix_phases
      [
        Phase.new(mode: :fix, tools: [ Locales, HerbFormat, Oxfmt, Prettier ]),
        Phase.new(mode: :fix, tools: [ Rubocop, Oxlint, Stylelint ]),
        Phase.new(mode: :check, tools: [ Syntax, HerbLint, Actionlint ])
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
        "**/*.{arb,gemspec,rake,rb,ru,ruby}",
        "**/Gemfile",
        "**/Rakefile",
        "bin/*"
      ].freeze

      def command(mode)
        return unless check?(mode)

        selected = RubySource.select(select(patterns: PATTERNS), root:)
        return if skip?(selected)

        [ "bin/syntax", *selected ]
      end
    end

    class Rubocop < Tool
      EXTRA_PATTERNS = [
        "**/*.erb",
        "**/Gemfile.*",
        "**/Rakefile.*"
      ].freeze

      def command(mode)
        selected = (ruby_sources + select(patterns: EXTRA_PATTERNS)).uniq
        return if skip?(selected)

        [ "bin/rubocop", *flags(mode), *targets(selected) ]
      end

      private

      def ruby_sources
        RubySource.select(select(patterns: Syntax::PATTERNS), root:)
      end

      def flags(mode)
        check?(mode) ? %w[--parallel --format simple] : %w[--parallel --autocorrect-all --format quiet]
      end

      def targets(selected)
        selected.empty? ? [] : [ "--only-recognized-file-types", *selected ]
      end
    end

    class Actionlint < Tool
      PATTERNS = %w[.github/workflows/**/*.{yml,yaml}].freeze

      def command(mode)
        return unless check?(mode)

        selected = select(patterns: PATTERNS, prefixes: %w[.github/workflows])
        return if skip?(selected)

        [ "bin/actionlint", *targets(selected) ]
      end

      private

      def targets(selected)
        selected.none? { |path| File.directory?(File.expand_path(path, root)) } ? selected : []
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
      TARGETS = [
        "app/assets/tailwind",
        "app/assets/stylesheets/mailer.css",
        "package.json",
        ".prettierrc",
        ".stylelintrc.json",
        ".oxfmtrc.json",
        ".oxlintrc.json"
      ].freeze
      DEFAULT_SCOPE = [
        "app/assets/tailwind/**/*.css",
        *TARGETS.drop(1)
      ].freeze

      def command(mode)
        selected = select_targets
        return if skip?(selected)

        [ "bin/prettier", *scope(selected), flag(mode), "--cache", "--log-level", "warn" ]
      end

      private

      def select_targets
        TARGETS.flat_map { |target| select(prefixes: [ target ]) }.uniq
      end

      def scope(selected)
        selected.empty? ? DEFAULT_SCOPE : selected
      end

      def flag(mode)
        check?(mode) ? "--check" : "--write"
      end
    end

    class Stylelint < Tool
      TARGETS = %w[app/assets/tailwind app/assets/stylesheets/mailer.css].freeze
      DEFAULT_SCOPE = %w[app/assets/tailwind/**/*.css app/assets/stylesheets/mailer.css].freeze

      def command(mode)
        selected = select_targets
        return if skip?(selected)

        [ "bin/stylelint", *scope(selected), *suffix(mode) ]
      end

      private

      def select_targets
        TARGETS.flat_map { |target| select(prefixes: [ target ]) }.uniq
      end

      def scope(selected)
        selected.empty? ? DEFAULT_SCOPE : selected
      end

      def suffix(mode)
        check?(mode) ? [] : [ "--fix" ]
      end
    end
  end
end
