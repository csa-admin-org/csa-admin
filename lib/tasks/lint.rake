# frozen_string_literal: true

namespace :lint do
  desc "Run Rubocop and Prettier to check code (no autocorrect)"
  task :check do
    puts "Running Rubocop..."
    rubocop_success = system("bin/rubocop --parallel")
    puts "Running Prettier..."
    prettier_success = system("npx prettier app --check")

    abort("Linting failed") unless rubocop_success && prettier_success
  end

  desc "Run Rubocop and Prettier with autocorrect"
  task :autocorrect do
    puts "Running locales format..."
    Rake::Task["locales:format"].invoke
    puts "Running Rubocop with autocorrect..."
    system("bin/rubocop --parallel --autocorrect-all") || abort("Rubocop autocorrect failed")
    puts "Running Prettier..."
    system("npx prettier app --write")
  end
end

# Alias bin/rails lint to lint:check
task lint: "lint:check"
