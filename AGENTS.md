# Agent Instructions

CSA Admin is a multi-tenant Rails application for managing Community Supported Agriculture organizations. Each tenant has its own SQLite database.

## Multi-Tenant Architecture

Separate SQLite databases per tenant (sharding). Tenant is resolved from request subdomain.

### Key Files

- `lib/tenant.rb` - Tenant switching logic
- `config/tenant.yml` - Tenant hosts configuration
- `app/jobs/concerns/tenant_context.rb` - Job tenant serialization

### Tenant Configuration

```yaml
# config/tenant.yml.example
test:
  acme:
    admin_host: admin.acme.test
    members_host: members.acme.test
```

### Tenant Commands

```ruby
Tenant.connect("acme")      # Connect (console only)
Tenant.disconnect           # Disconnect (console only)
Tenant.switch("acme") { }   # Execute block in tenant context
Tenant.switch_each { }      # Execute block for each tenant
Tenant.current              # Get current tenant name
```

### Current Context

```ruby
Current.org       # Organization singleton (tenant settings/features)
Current.session   # Current user session
```

## Database

```bash
bin/rails db:migrate              # Migrate all tenants
bin/rails db:rollback             # Rollback all tenants (specify steps w/ STEP=n)
bin/rails db:reset RAILS_ENV=test # Reset test database
```

## Tests

```bash
bin/rails test:all  # Run all tests (uses "acme" tenant)
```

## Background Jobs

Jobs inherit from `ApplicationJob` which includes `TenantContext` for automatic tenant serialization.

```ruby
# Run job across all tenants
TenantSwitchEachJob.perform_later("MyJobClassName")
```

## Code Style

- `frozen_string_literal: true` pragma required in all Ruby files

## Commit Messages

- Review all staged changes before writing
- Keep it short (a few sentences max)
- Explain why the change is needed, not just what changed
