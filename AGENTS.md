# Agent Instructions

## What is CSA Admin?

CSA Admin is a multi-tenant Rails application for managing Community Supported Agriculture organizations. Each tenant has its own isolated SQLite database.

## Development Commands

- `bin/ci` — Full CI suite (lint, security, tests, seeds) — steps defined in `config/ci.rb`
- `bin/rails test:all` — All tests, unit + system (uses "acme" tenant)
- `bin/rails lint:check` / `lint:autocorrect` — Style checks
- **Minitest** with fixtures (`test/fixtures/`), no factories. System tests use Capybara.

## Multi-Tenant Architecture

Tenant is resolved from request subdomain. Each tenant has a separate SQLite database.

```ruby
Tenant.switch("acme") { }   # Execute block in tenant context
Tenant.switch_each { }      # Execute block for each tenant
Tenant.current              # Get current tenant name
Current.org                 # Organization singleton (tenant settings/features)
```

Key files: `lib/tenant.rb`, `config/tenant.yml`

Jobs inherit from `ApplicationJob` which includes `TenantContext` for automatic tenant serialization. Use `TenantSwitchEachJob.perform_later("MyJobClassName")` to run a job across all tenants.

## Database & Migrations

Standard Rails database tasks (`db:migrate`, `db:rollback`, `db:schema:load`, etc.) work as expected and automatically apply to all tenant databases. Custom overrides in `lib/tasks/database.rake` ensure multi-tenant compatibility.

```bash
bin/rails db:migrate              # Run pending migrations (all tenants)
bin/rails db:rollback             # Rollback last migration (all tenants, STEP=n supported)
bin/rails db:migrate:down VERSION=xxx  # Run down for a specific migration (all tenants)
bin/rails db:schema:load          # Load schema into all tenant databases
```

Key file: `lib/tasks/database.rake`

## Code Style

### Vanilla Rails is Plenty

Prefer Rails conventions over custom abstractions. Use models, concerns, and built-in Rails patterns first. Avoid unnecessary service objects, query objects, or form objects. Complexity should be earned, not assumed.

### Rich Models

Put business logic in models. When a model grows:
1. Extract cohesive functionality into sub-model concerns (e.g., `app/models/member/billing.rb`)
2. Delegate complex operations to POROs in `app/models/` (e.g., `app/models/billing/invoicer.rb`)

Shared concerns go in `app/models/concerns/`. When including multiple concerns, document callback order dependencies.

### Minimal Comments

Code should speak for itself. Use clear naming and small methods instead of comments. Only add comments to explain **why** something non-obvious is done, never **what** the code does. No `@param`/`@return` yard-style docs — this is an app, not a public API gem.

## ActiveAdmin

Admin interface built on ActiveAdmin. Resource files: `app/admin/`.
Custom DSL extensions (panel icons, fieldset icons): `lib/active_admin/`.
See `DESIGN.md` for icon and panel conventions.

## Frontend

- **Importmap** (no JS bundler), **Tailwind CSS**, **Turbo + Stimulus**
- Icons from Lucide (see `DESIGN.md`)

## Translations

See `TRANSLATIONS.md` for locale file conventions, two-phase workflow, and voice & tone rules per language.

## GDPR & Member Privacy

Anonymized members must not have their `member_id` exposed in CSV/XLSX exports.

**Convention:** Use `member&.display_id` instead of `member_id` or `member.id` in all export code:

```ruby
# ❌ Bad - leaks member_id for anonymized members
column(:member_id)
column(:member_id, &:member_id)

# ✅ Good - returns nil for anonymized members
column(:member_id) { |record| record.member&.display_id }
```

A test in `test/models/member/discardable_test.rb` automatically scans export files for dangerous patterns.

Key files: `app/models/member/discardable.rb`, `app/models/member/anonymization.rb`
