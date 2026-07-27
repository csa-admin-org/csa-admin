# Agent Instructions

## Project Context

CSA Admin is a multi-tenant Rails application for managing Community Supported Agriculture organizations. Each tenant has its own isolated SQLite database, resolved from the request host. Read `.agents/glossary.md` when working with unfamiliar domain terminology.

## Development and Validation

- `bin/rails test:all` — full unit and system test suite using the `acme` test tenant
- `bin/ci` — final validation: setup, style, security, tests, and seeds; see `config/ci.rb`
- While iterating, run individual tools as needed (`bin/rubocop`, `bin/locales`, `bin/syntax`, `bin/herb`, …). 
- `mise bootstrap` installs local tools and native packages, then runs `bin/setup --skip-server`; continue using `bin/rails` and `bin/ci` directly.
- Tests use Minitest, all fixtures in `test/fixtures/`, and Capybara for system tests.
- Tests run in parallel and block real HTTP through WebMock. Stub external requests and avoid mutable process-global test state.

## Multi-Tenant Invariants

- Tenant APIs live in `lib/tenant.rb`; configuration lives in `config/tenant.yml`.
- Use `Tenant.switch(name) { ... }` for one tenant and `Tenant.switch_each { ... }` for cross-tenant work. `Tenant.current` identifies the current tenant; `Current.org` is its organization singleton.
- Never query tenant models outside a tenant context, nest switches to different tenants, or carry Active Record objects across tenant boundaries.
- `TENANT` restricts `Tenant.all`, including tenant-wide database and maintenance tasks.

### Local Browser Access

Development uses puma-dev over HTTPS, not `localhost:3000`. Host mapping, portals, and agent-browser notes: `.agents/browser/README.md`.

### Jobs

Tenant-scoped jobs inherit from `ApplicationJob`, which serializes `Tenant.current` and `Current`. Enqueue them with `perform_later` from inside a tenant context; do not call `perform_now` on them. Cross-tenant orchestrators may inherit from `ActiveJob::Base`, switch tenants, and enqueue tenant-scoped jobs. Use `TenantSwitchEachJob.perform_later("MyJobClassName")` for the standard fan-out pattern.

### Database and Migrations

Standard Rails database tasks are tenant-aware through `lib/tasks/database.rake` and operate on `Tenant.all`. Remember that `TENANT` may intentionally restrict that set.

## Tenant-Aware Application Behavior

- Do not assume a feature is enabled for every organization. Gate feature-specific behavior with `Current.org.feature?` and existing feature helpers.
- ActiveAdmin uses CanCan through `Ability`; custom admin actions must explicitly authorize their operation.
- Business years are organization-specific fiscal years. Use `Current.fiscal_year` or `Current.org.fiscal_year_for`, not `Date.current.year`, for delivery and billing logic.
- Many records use `Discardable`. Respect `.kept`, `can_destroy?`, `can_discard?`, and model `destroy` behavior; do not bypass lifecycle rules with direct deletion or bulk updates.
- CSV/XLSX exports must use `member&.display_id`, never raw `member_id` or `member.id`, so anonymized members remain unlinkable. This is enforced by `test/models/member/discardable_test.rb`.

## Implementation Style

- Prefer vanilla Rails and rich models over service, query, or form object layers. Extract cohesive model concerns or model-layer POROs when complexity requires it.
- Model-specific concerns live under the model namespace (for example, `app/models/member/billing.rb`); shared concerns live in `app/models/concerns/`.
- ActiveAdmin resources live in `app/admin/`; custom DSL extensions live in `lib/active_admin/`. Follow `DESIGN.md` for interface and icon conventions.
- Frontend uses Importmap, Turbo, Stimulus, Tailwind CSS, and Lucide. Do not introduce a JavaScript bundler without an explicit requirement.

## High-Risk Domains

### Banking and Payments

Payment credentials live only in tenant-local `bank_connections`. Resolve runtime providers through `Current.org.active_bank_connection` / `Current.org.bank_connection`. Runtime and new EBICS connections support H005/BTF only; do not restore legacy organization credential columns or add H003/H004/order-type fallback paths. Follow `docs/bank_connections.md` for setup and recovery procedures.

### Translations

Follow `TRANSLATIONS.md` for any user-facing copy, locale, mail, or newsletter change. Request base keys in application code, place scopes before `_html`, preserve the required scoped fallback matrix, and never overwrite tenant-customized mail or newsletter content when changing source defaults.
