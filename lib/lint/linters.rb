# frozen_string_literal: true

module Lint
  module Linters
    def self.all
      [
        Locales,
        Rubocop,
        HerbLint,
        HerbFormat,
        Oxfmt,
        Oxlint,
        Prettier,
        Stylelint
      ]
    end

    class Locales < Linter
      def command(mode)
        return if skip?(select(patterns: %w[config/locales/**/*.{yml,yaml}], prefixes: %w[config/locales]))

        check?(mode) ? "bin/rails locales:check" : "bin/rails locales:format"
      end
    end

    class Rubocop < Linter
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

        "bin/rubocop #{flags(mode)}#{targets(selected)}"
      end

      private

      def flags(mode)
        check?(mode) ? "--parallel --format simple" : "--parallel --autocorrect-all --format quiet"
      end

      def targets(selected)
        return "" if selected.empty?

        " --only-recognized-file-types #{join(selected)}"
      end
    end

    class HerbLint < Linter
      def command(mode)
        return unless check?(mode)

        selected = select(patterns: HerbFormat::PATTERNS)
        return if skip?(selected)

        "bin/herb lint #{scope(selected)}"
      end

      private

      def scope(selected)
        selected.empty? ? "." : join(selected)
      end
    end

    class HerbFormat < Linter
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

        "bin/herb format #{scope(selected)}#{suffix(mode)}"
      end

      private

      def scope(selected)
        selected.empty? ? "." : join(selected)
      end

      def suffix(mode)
        check?(mode) ? " --check" : ""
      end
    end

    class Oxfmt < Linter
      def command(mode)
        selected = select(prefixes: %w[app/javascript])
        return if skip?(selected)

        "bin/oxfmt #{scope(selected)}#{suffix(mode)}"
      end

      private

      def scope(selected)
        selected.empty? ? "app/javascript" : join(selected)
      end

      def suffix(mode)
        check?(mode) ? " --check" : ""
      end
    end

    class Oxlint < Linter
      def command(mode)
        selected = select(prefixes: %w[app/javascript])
        return if skip?(selected)

        "bin/oxlint #{scope(selected)}#{suffix(mode)}"
      end

      private

      def scope(selected)
        selected.empty? ? "app/javascript" : join(selected)
      end

      def suffix(mode)
        check?(mode) ? "" : " --fix"
      end
    end

    class Prettier < Linter
      def command(mode)
        selected = select(patterns: %w[app/assets/tailwind/**/*.css], prefixes: %w[app/assets/tailwind])
        return if skip?(selected)

        "bin/prettier #{scope(selected)} #{flag(mode)} --cache --log-level warn"
      end

      private

      def scope(selected)
        selected.empty? ? '"app/assets/tailwind/**/*.css"' : join(selected)
      end

      def flag(mode)
        check?(mode) ? "--check" : "--write"
      end
    end

    class Stylelint < Linter
      def command(mode)
        selected = select(patterns: %w[app/assets/tailwind/**/*.css], prefixes: %w[app/assets/tailwind])
        return if skip?(selected)

        "bin/stylelint #{scope(selected)}#{suffix(mode)}"
      end

      private

      def scope(selected)
        selected.empty? ? '"app/assets/tailwind/**/*.css"' : join(selected)
      end

      def suffix(mode)
        check?(mode) ? "" : " --fix"
      end
    end
  end
end
