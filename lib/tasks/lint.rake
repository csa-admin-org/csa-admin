# frozen_string_literal: true

require "parallel"

namespace :lint do
  LINT_TYPES = %i[locales rubocop herb prettier]

  def parallel_lint(&block)
    results = {}
    Parallel.map(LINT_TYPES) do |type|
      cmd = block.call(type)
      if cmd.present?
        puts "Running #{type}..."
        results[type] = system(cmd)
      end
    end
    abort("Linting failed") unless results.compact.all?
  end

  desc "Run Rubocop and Prettier to check code (no autocorrect)"
  task :check do
    parallel_lint do |type|
      case type
      when :locales
        "bin/rails locales:check"
      when :rubocop
        "bin/rubocop --parallel --format simple"
      when :herb
        "npm run herb:format:check **/*.html"
      when :prettier
        "npx prettier app --check --cache --log-level warn"
      end
    end
  end

  desc "Run Rubocop and Prettier with autocorrect"
  task :autocorrect do
    parallel_lint do |type|
      case type
      when :locales
        "bin/rails locales:format"
      when :rubocop
        "bin/rubocop --parallel --autocorrect-all --format quiet"
      when :herb
        "npm run herb:format"
      when :prettier
        "npx prettier app --write --cache --log-level warn"
      end
    end
  end
end

# Alias bin/rails lint to lint:check
task lint: "lint:check"
