# frozen_string_literal: true

require "lint"

Lint.register_path_arguments!

namespace :lint do
  desc "Run Rubocop, Herb, Oxfmt (JS), Oxlint (JS), Prettier (CSS), and Stylelint (CSS) to check code (no autocorrect). Optional paths: bin/rails lint:check path [path...]"
  task :check do
    Lint.run(:check)
  end

  desc "Run Rubocop, Herb, Oxfmt (JS), Oxlint (JS), Prettier (CSS), and Stylelint (CSS) with autocorrect. Optional paths: bin/rails lint:autocorrect path [path...]"
  task :autocorrect do
    Lint.run(:autocorrect)
  end
end

# Alias bin/rails lint to lint:check
task lint: "lint:check"
