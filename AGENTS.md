# Agent Instructions

CSA Admin is a multi-tenant Rails app for Community Supported Agriculture organizations. Each tenant is an isolated SQLite database, resolved from the request host, not an `org_id` column. Domain terms: `GLOSSARY.md` and the `glossary` skill.

## Commands

- Iterate with filtered `bin/ci` (`-g style|security|tests`, `-s "Style: RuboCop"`, `-f`). Names match `config/ci.rb`.
- Full tests: `bin/rails test:all` (`acme` tenant). Minitest, Capybara, parallel, WebMock; stub HTTP, no process-global mutable state.
- Final: `bin/ci`.
- Setup: `mise bootstrap`. Upgrades: `bin/update` (review the diff).
- `bin/ci` `--group`/`--step` is `config/ci_filter.rb` until upstream Rails has both. Groups themselves are upstream.

## Tenant

`lib/tenant.rb`, `config/tenant.yml`.

- One tenant: `Tenant.switch(name) { ... }`. Cross-tenant: `Tenant.switch_each`. Current: `Tenant.current`, `Current.org`.
- Never query tenant models outside a switch, nest switches to another tenant, or carry Active Record objects across tenants.
- `TENANT` restricts `Tenant.all`, including db tasks in `lib/tasks/database.rake`.
- Tenant jobs inherit `ApplicationJob`; `perform_later` from inside a switch, never `perform_now`. Fan-out: `TenantSwitchEachJob.perform_later("MyJobClassName")`. Cross-tenant orchestrators inherit `ActiveJob::Base`.
- Gate features with `Current.org.feature?`. Fiscal years: `Current.fiscal_year` or `Current.org.fiscal_year_for`, not `Date.current.year`.
- Discardable: `.kept`, `can_destroy?`, `can_discard?`. Exports: `member&.display_id`, never `member.id` (`test/models/member/discardable_test.rb`).

Dev: `bin/dev`. Hosts and auth: `browser` skill. `acme` is test-only.

## Code

Vanilla Rails, rich models. No service, query, or form objects. `Archspec.rb` enforces that. The Query API under `app/models/query` is allowed; Archspec forbids query objects in `app/queries`. Model concerns: `app/models/member/billing.rb`; shared: `app/models/concerns/`.

ActiveAdmin: `app/admin/`, DSL `config/initializers/active_admin_*` and `app/admin/components`. Custom actions must authorize via `Ability`. UI: `DESIGN.md`.

Importmap, Turbo, Stimulus, Lucide, no-build CSS.

PDFs: `PDF::Base` (`sghtmltopdf`), ERB views under `app/views/pdfs/`, CSS under `app/assets/stylesheets/pdf/`, Liberation fonts under `lib/assets/fonts/`; `PDF::InvoiceCancellationStamp` uses HexaPDF.

Copy: `TRANSLATIONS.md` and the `translations` skill. Never overwrite tenant-customized mail or newsletter content when changing source defaults.

## Tests

- `with_tenant` only sets the thread-local name. Another shard is `with_connected_tenant`.
- Do not merge `membership_*_test.rb` with `test/models/membership/`. They are different classes.
- After `travel_to` across a fiscal year, `Current.reset`. Dates stay inside the fixture window. Do not stretch fixtures to the current year.
- System tests are rack_test. A green one is not Stimulus coverage.

## Hands off

Leave `db/schema.rb`, `db/queue_schema.rb`, applied migrations, tenant SQLite files, credentials, and `config/tenant.yml` hosts alone unless that is the task. Do not re-enable `db:prepare` in `bin/docker-entrypoint`.

Production deploys from `master` after CI via `.github/workflows/deploy.yml`. Tenant and queue migrations run in `.kamal/hooks/pre-deploy` on the new image.

## Hot Cell

Active Storage image processing runs in the `activestorage-hotcell` Kamal accessory (`config/deploy.yml`). Cell image inputs: `hotcell/`.

- Dev: `bin/dev` starts the local process through `bin/hotcell-dev`.
- Tests: `TestHotCellServer` (`test/support/hot_cell_server.rb`), started from `test/test_helper.rb`.
- Deploy: `.github/workflows/deploy.yml` runs `bin/hotcell-release` before `bundle exec kamal deploy`. The script exits when that accessory is already running the current image; otherwise it builds, pushes, and boots or reboots it. `--force` rebuilds and reboots even when the tag is unchanged.

## Banking

Credentials only on tenant-local `bank_connections`. Runtime: `Current.org.active_bank_connection` / `Current.org.bank_connection`. H005/BTF only; no org credential columns, no H003/H004. Setup: `docs/bank_connections.md`.
