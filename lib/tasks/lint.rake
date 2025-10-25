# frozen_string_literal: true

namespace :lint do
  desc "Run Rubocop and Prettier to check code (no autocorrect)"
  task :check do
    puts "Checking Locales..."
    locales_success = system("bin/rails locales:check")
    puts "Checking Rubocop..."
    rubocop_success = system("bin/rubocop --parallel --format simple")
    puts "Checking Prettier..."
    prettier_success = system("npx prettier app --check --cache")

    abort("Linting failed") unless locales_success && rubocop_success && prettier_success
  end

  desc "Run Rubocop and Prettier with autocorrect"
  task :autocorrect do
    puts "Formatting locales..."
    system("bin/rails locales:format")
    puts "Running Rubocop..."
    system("bin/rubocop --parallel --autocorrect-all --format quiet") || abort("Rubocop autocorrect failed")
    puts "Running htmlbeautifier..."
    system("bin/htmlbeautifier app/views/**/*.html.erb --keep-blank-lines 1")
    puts "Running Prettier..."
    system("npx prettier app --check --write --cache --log-level warn")
  end
end

# Alias bin/rails lint to lint:check
task lint: "lint:check"
