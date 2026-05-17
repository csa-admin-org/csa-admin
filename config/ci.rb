# frozen_string_literal: true

# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Locales", "bin/rails locales:check"
  step "Style: RuboCop", "bin/rubocop --parallel --format simple"
  step "Style: Herb format", "bin/herb format . --check"
  step "Style: Herb lint", "bin/herb lint ."
  step "Style: Oxfmt (JS)", "bin/oxfmt app/javascript --check"
  step "Style: Oxlint (JS)", "bin/oxlint app/javascript"
  step "Style: Prettier (CSS)", 'bin/prettier "app/assets/tailwind/**/*.css" --check --cache --log-level warn'
  step "Style: Stylelint (CSS)", 'bin/stylelint "app/assets/tailwind/**/*.css"'

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: Rails", "bin/rails test:all"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
