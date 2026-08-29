# frozen_string_literal: true

# Run using bin/ci
#
# Full-project checks only (no path filter, no autofix). Individual tools still
# support their own fix flags when needed.
#
# Groups and --group/--step filtering use a temporary Rails edge polyfill in
# lib/rails_edge/ until upstream Rails provides both. Examples:
#
#   bin/ci -g style
#   bin/ci -s "Style: RuboCop"
#   bin/ci -g security -f

CI.run do
  step "Setup", "bin/setup", "--skip-server"

  group "Style", parallel: 8 do
    step "Style: Locales", "bin/locales", "check"
    step "Style: Herb format", "bin/herb", "format", ".", "--check"
    step "Style: Oxfmt", "bin/oxfmt", "app/javascript", "--check"
    step "Style: Prettier",
      "bin/prettier",
      "app/assets/stylesheets/**/*.css",
      "package.json",
      ".prettierrc",
      ".stylelintrc.json",
      ".oxfmtrc.json",
      ".oxlintrc.json",
      "--check",
      "--cache",
      "--log-level",
      "warn"
    step "Style: RuboCop", "bin/rubocop", "--parallel", "--format", "simple"
    step "Style: Oxlint", "bin/oxlint", "app/javascript"
    step "Style: Stylelint",
      "bin/stylelint",
      "app/assets/stylesheets/**/*.css"
    step "Style: Herb lint", "bin/herb", "lint", "."
    step "Style: Actionlint", "bin/actionlint"
    step "Style: Solid Queue", "bin/jobs", "check"
  end

  group "Security", parallel: 4 do
    step "Security: Bundler audit", "bin/bundler-audit", "check", "--update"
    step "Security: Importmap", "bin/importmap", "audit"
    step "Security: Brakeman", "bin/brakeman", "--quiet", "--no-pager", "--exit-on-warn", "--exit-on-error"
    step "Security: Aube", "bin/aube", "audit"
  end

  group "Tests" do
    step "Tests: Rails", "bin/rails", "test:all"
    step "Tests: Seeds", "env", "RAILS_ENV=test", "bin/rails", "db:seed:replant"
  end

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
