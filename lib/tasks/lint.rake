# frozen_string_literal: true

require "parallel"

namespace :lint do
  lint_types = %i[locales rubocop herb_lint herb_format oxfmt oxlint prettier stylelint]

  parallel_lint = lambda do |&block|
    results = Parallel.map(lint_types) do |type|
      cmd = block.call(type)
      if cmd.present?
        puts "Running #{type}..."
        system(cmd)
      end
    end
    abort("Linting failed") unless results.compact.all?
  end

  desc "Run Rubocop, Herb, Oxfmt (JS), Oxlint (JS), Prettier (CSS), and Stylelint (CSS) to check code (no autocorrect)"
  task :check do
    parallel_lint.call do |type|
      case type
      when :locales
        "bin/rails locales:check"
      when :rubocop
        "bin/rubocop --parallel --format simple"
      when :herb_lint
        "bin/herb lint ."
      when :herb_format
        "bin/herb format . --check"
      when :oxfmt
        "bin/oxfmt app/javascript --check"
      when :oxlint
        "bin/oxlint app/javascript"
      when :prettier
        'bin/prettier "app/assets/tailwind/**/*.css" --check --cache --log-level warn'
      when :stylelint
        'bin/stylelint "app/assets/tailwind/**/*.css"'
      end
    end
  end

  desc "Run Rubocop, Herb, Oxfmt (JS), Oxlint (JS), Prettier (CSS), and Stylelint (CSS) with autocorrect"
  task :autocorrect do
    parallel_lint.call do |type|
      case type
      when :locales
        "bin/rails locales:format"
      when :rubocop
        "bin/rubocop --parallel --autocorrect-all --format quiet"
      when :herb_format
        "bin/herb format ."
      when :oxfmt
        "bin/oxfmt app/javascript"
      when :oxlint
        "bin/oxlint app/javascript --fix"
      when :prettier
        'bin/prettier "app/assets/tailwind/**/*.css" --write --cache --log-level warn'
      when :stylelint
        'bin/stylelint "app/assets/tailwind/**/*.css" --fix'
      end
    end
  end
end

# Alias bin/rails lint to lint:check
task lint: "lint:check"
