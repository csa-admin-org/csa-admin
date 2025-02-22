# frozen_string_literal: true

namespace :lint do
  desc "Run Rubocop and ERB Lint to check code (no autocorrect)"
  task :check do
    puts "Running Rubocop..."
    rubocop_success = system("bin/rubocop --parallel")
    puts "Running ERB Lint..."
    erb_lint_success = system("bin/erb_lint --lint-all")

    abort("Linting failed") unless rubocop_success && erb_lint_success
  end

  desc "Run Rubocop and ERB Lint with autocorrect"
  task :autocorrect do
    puts "Running Rubocop with autocorrect..."
    system("bin/rubocop --parallel --autocorrect-all") || abort("Rubocop autocorrect failed")
    puts "Running ERB Lint with autocorrect..."
    system("bin/erb_lint --lint-all --autocorrect") || abort("ERB Lint autocorrect failed")
  end
end

# Alias bin/rails lint to lint:check
task lint: "lint:check"
