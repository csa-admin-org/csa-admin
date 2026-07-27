# frozen_string_literal: true

# Run using bin/ci
#
# Full-project checks only (no path filter, no autofix). Individual tools still
# support their own fix flags when needed. Parallel `group` support lands with
# Rails 8.2+; until then steps run serially.

CI.run do
  step "Setup", "bin/setup", "--skip-server"

  step "Style: Locales", "bin/locales", "check"
  step "Style: Herb format", "bin/herb", "format", ".", "--check"
  step "Style: Oxfmt", "bin/oxfmt", "app/javascript", "--check"
  step "Style: Prettier",
    "bin/prettier",
    "app/assets/tailwind/**/*.css",
    "app/assets/stylesheets/mailer.css",
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
    "app/assets/tailwind/**/*.css",
    "app/assets/stylesheets/mailer.css"
  step "Style: Syntax", "bin/syntax"
  step "Style: Herb lint", "bin/herb", "lint", "."
  step "Style: Actionlint", "bin/actionlint"

  step "Security: Bundler audit", "bin/bundler-audit", "check", "--update"
  step "Security: Importmap", "bin/importmap", "audit"
  step "Security: Brakeman", "bin/brakeman", "--quiet", "--no-pager", "--exit-on-warn", "--exit-on-error"
  step "Security: Aube", "bin/aube", "audit"

  step "Tests: Rails", "bin/rails", "test:all"
  step "Tests: Seeds", "env", "RAILS_ENV=test", "bin/rails", "db:seed:replant"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
