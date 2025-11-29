# Agent Instructions

This document provides guidance for AI agents working with this codebase.

## Project Overview

CSA Admin is a multi-tenant Rails application for managing Community Supported Agriculture organizations. Each tenant has its own SQLite database.

## Multi-Tenant Architecture

This project uses a **custom multi-tenant setup** with separate SQLite databases per tenant.

### Key Files

- `lib/tenant.rb` - Main tenant module with switching logic
- `lib/tenant/middleware.rb` - Request tenant resolution
- `config/tenant.yml` - Tenant configuration (hosts, aliases, state)
- `app/jobs/concerns/tenant_context.rb` - Job tenant serialization

### Tenant Commands

```ruby
# In Rails console
Tenant.connect("acme")      # Connect to a tenant
Tenant.disconnect           # Disconnect from tenant
Tenant.switch("acme") { }   # Execute block in tenant context
Tenant.current              # Get current tenant name
Tenant.all                  # List all tenants
```

## Database Migrations

### After Creating a New Migration

Simply run:

```bash
bin/rails db:migrate
```

This will:
1. Run the migration on all tenant databases
2. Automatically update `db/schema.rb`

### Resetting the Test Database

```bash
bin/rails db:reset RAILS_ENV=test
```

### Rolling Back All Tenants

```bash
bin/rails db:rollback:all VERSION=20240101120000
```

## Running Tests

```bash
# Run all tests
bin/rails test:all

# Run a specific test file
bin/rails test test/models/member_test.rb

# Run a specific test
bin/rails test test/models/member_test.rb:42
```

Tests automatically connect to the `acme` tenant (defined in `config/tenant.yml` under `test:`).

## Code Style

- Use `frozen_string_literal: true` pragma in all Ruby files
- Follow Rails conventions
- Use `Current.org` to access current organization settings within a tenant context

## Common Patterns

### Accessing Tenant-Specific Data

Always ensure code runs within a tenant context:

```ruby
# In controllers/views - automatic via middleware
Current.org.name

# In jobs - automatic via TenantContext concern
class MyJob < ApplicationJob
  def perform
    # Tenant context is automatically restored
    Current.org.some_setting
  end
end

# In console or scripts
Tenant.switch("tenant_name") do
  # Your code here
end
```

### Creating Jobs That Run Across All Tenants

```ruby
# Enqueue a job to run for each tenant
TenantSwitchEachJob.perform_later("MyJob")
```
