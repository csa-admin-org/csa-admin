# Agent Instructions

## What is CSA Admin?

CSA Admin is a multi-tenant Rails application for managing Community Supported Agriculture organizations. Each tenant has its own isolated SQLite database.

## Development Commands

```bash
bin/rails test:all                # Run all tests (uses "acme" tenant)
bin/rails lint:check              # Check for style issues
bin/rails lint:autocorrect        # Auto-fix style issues
```

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

## Code Style

### Vanilla Rails is Plenty

Prefer Rails conventions over custom abstractions. Use models, concerns, and built-in Rails patterns first. Avoid unnecessary service objects, query objects, or form objects. Complexity should be earned, not assumed.

### Rich Models

Put business logic in models. When a model grows:
1. Extract cohesive functionality into sub-model concerns (e.g., `app/models/member/billing.rb`)
2. Delegate complex operations to POROs in `app/models/` (e.g., `app/models/billing//invoicer.rb`)

Shared concerns go in `app/models/concerns/`. When including multiple concerns, document callback order dependencies.

### Documenting Complex Classes

When creating non-trivial classes, add a comment block explaining why it exists, what problem it solves, and how it's used.

## Translations Workflow

Supported languages: English (`en`), French (`fr`), German (`de`), Italian (`it`), Dutch (`nl`).

YAML locale files use language-prefixed keys:
```yaml
members:
  title:
    _en: Members
    _fr: Membres
```

Template files use language suffixes: `invoice_created.en.liquid`, `invoice_created.fr.liquid`

**Two-phase process:**
1. During development, only add `_en` and `_fr` translations
2. Once finalized, add `_de`, `_it`, `_nl` translations

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

## Commits

- **Never auto-commit** — always propose the commit message and wait for confirmation
- **Always run `bin/rails test:all`** before proposing a commit
- **One logical change per commit** — discuss splitting if needed
- Keep messages short, explain **why** the change is needed
