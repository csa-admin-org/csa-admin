# Agent Instructions

CSA Admin is a multi-tenant Rails app for Community Supported Agriculture organizations. Each tenant is an isolated SQLite database, resolved from the request host, not an `org_id` column. Domain terms: `.agents/glossary.md`.

## Commands

- Iterate with filtered `bin/ci` (`-g style|security|tests`, `-s "Style: RuboCop"`, `-f`). Names match `config/ci.rb`.
- Full tests: `bin/rails test:all` (`acme` tenant). Minitest, Capybara, parallel, WebMock; stub HTTP, no process-global mutable state.
- Final: `bin/ci`. Single-tool wrappers: `bin/rubocop`, `bin/locales`, `bin/herb`, `bin/jobs check`.
- Setup: `mise bootstrap`. Upgrades: `bin/update` (review the diff).
- `bin/ci` `--group`/`--step` polyfill lives in `lib/rails_edge/` until upstream Rails has both.

## Tenant

`lib/tenant.rb`, `config/tenant.yml`.

- One tenant: `Tenant.switch(name) { ... }`. Cross-tenant: `Tenant.switch_each`. Current: `Tenant.current`, `Current.org`.
- Never query tenant models outside a switch, nest switches to another tenant, or carry Active Record objects across tenants.
- `TENANT` restricts `Tenant.all`, including db tasks in `lib/tasks/database.rake`.
- Tenant jobs inherit `ApplicationJob`; `perform_later` from inside a switch, never `perform_now`. Fan-out: `TenantSwitchEachJob.perform_later("MyJobClassName")`. Cross-tenant orchestrators inherit `ActiveJob::Base`.
- Gate features with `Current.org.feature?`. Fiscal years: `Current.fiscal_year` or `Current.org.fiscal_year_for`, not `Date.current.year`.
- Discardable: `.kept`, `can_destroy?`, `can_discard?`. Exports: `member&.display_id`, never `member.id` (`test/models/member/discardable_test.rb`).

Dev: `bin/dev` on `http://*.localhost:3000` (`DEV_ORIGIN=localhost`), or puma-dev on `https://*.test`. Hosts: `.agents/browser/README.md`. `acme` is test-only.

## Code

Vanilla Rails, rich models. No service, query, or form objects. Model concerns: `app/models/member/billing.rb`; shared: `app/models/concerns/`.

ActiveAdmin: `app/admin/`, DSL `lib/active_admin/`. Custom actions must authorize via `Ability`. UI: `DESIGN.md`.

Importmap, Turbo, Stimulus, Lucide, no-build CSS.

Copy: `TRANSLATIONS.md` and the `translations` skill. Never overwrite tenant-customized mail or newsletter content when changing source defaults.

## Hands off

Leave `db/schema.rb`, `db/queue_schema.rb`, applied migrations, tenant SQLite files, credentials, and `config/tenant.yml` hosts alone unless that is the task. Do not re-enable `db:prepare` in `bin/docker-entrypoint`.

Production deploys from `master` after CI via `.github/workflows/deploy.yml`. Tenant and queue migrations run in `.kamal/hooks/pre-deploy` on the new image.

## Banking

Credentials only on tenant-local `bank_connections`. Runtime: `Current.org.active_bank_connection` / `Current.org.bank_connection`. H005/BTF only; no org credential columns, no H003/H004. Setup: `docs/bank_connections.md`.
