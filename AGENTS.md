# Agent Instructions

This file provides guidance to AI coding agents working with this repository.

## What is CSA Admin?

CSA Admin is a multi-tenant Rails application for managing Community Supported Agriculture organizations. It handles member management, deliveries, baskets, billing, and communication for CSA farms. Each tenant (organization) has its own isolated SQLite database.

## Development Commands

### Setup and Server
```bash
bin/setup              # Initial setup (installs gems, creates DB, loads schema)
bin/dev                # Start development server
```

### Testing
```bash
bin/rails test:all                        # Run all tests (uses "acme" tenant)
bin/rails test test/path/to/file_test.rb  # Run single test file
bin/rails test test/path/to/file_test.rb:42  # Run single test at line
```

### Linting
```bash
bin/rails lint:check       # Check for style issues
bin/rails lint:autocorrect # Auto-fix style issues
```

### Database
```bash
bin/rails db:migrate              # Migrate all tenants
bin/rails db:rollback             # Rollback all tenants (specify steps w/ STEP=n)
bin/rails db:reset RAILS_ENV=test # Reset test database
```

## Architecture Overview

### Technology Stack

- **Ruby/Rails**: See `.ruby-version` and `Gemfile`
- **Database**: SQLite (one database per tenant)
- **Testing**: Minitest and fixtures
- **Frontend**: Turbo, Stimulus, Tailwind CSS, importmap
- **Background Jobs**: Solid Queue (ActiveJob)
- **Authorization**: CanCanCan
- **Admin UI**: ActiveAdmin
- **Monitoring**: AppSignal

### Project Structure

```
app/
├── admin/          # ActiveAdmin resources
├── controllers/    # Standard Rails controllers
├── helpers/        # View helpers
├── inputs/         # Custom form inputs
├── javascript/     # Stimulus controllers
├── jobs/           # Background jobs
├── mailers/        # ActionMailer classes
├── models/         # ActiveRecord models and concerns
└── views/          # ERB templates
```

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

## Background Jobs

Jobs inherit from `ApplicationJob` which includes `TenantContext` for automatic tenant serialization.

```ruby
# Run job across all tenants
TenantSwitchEachJob.perform_later("MyJobClassName")
```

## Code Style

### Vanilla Rails is Plenty

Prefer Rails conventions over custom abstractions. Before adding new patterns, architectural layers, or dependencies, ask: "Can Rails handle this out of the box?"

- Use models, concerns, and built-in Rails patterns first
- Avoid unnecessary service objects, query objects, or form objects
- Keep it simple - complexity should be earned, not assumed

**Essential reading:** [Vanilla Rails is Plenty](https://dev.37signals.com/vanilla-rails-is-plenty/)

### General Guidelines

- `frozen_string_literal: true` pragma required in all Ruby files
- Uses `rubocop-rails-omakase` as base configuration
- Keep controllers thin, push logic to models
- Use concerns to organize related model behavior

### Models Should Be Rich

Put business logic in models, but "rich" doesn't mean "fat". Aim for natural, expressive APIs - not god objects with spaghetti code.

When a model grows, avoid the "fat model" problem:

1. **Use concerns** - Extract cohesive functionality into sub-model concerns (e.g., `Member::Billable`)
2. **Delegate to POROs** - For complex operations, create plain Ruby objects in `app/models/`

```ruby
# Controller stays simple
class Baskets::DeliveriesController < ApplicationController
  def create
    @basket.deliver  # Natural API - complexity hidden in model/concerns/POROs
  end
end

# Model orchestrates, delegates complex operations
class Basket < ApplicationRecord
  include Deliverable

  def duplicate_to(member)
    Basket::Duplicator.new(self, member:).duplicate
  end
end

# app/models/basket/duplicator.rb - PORO for complex operation
class Basket::Duplicator
  def initialize(basket, member:)
    @basket = basket
    @member = member
  end

  def duplicate
    # Complex duplication logic lives here, not in the model
  end
end
```

This is just good object-oriented design - no special framework needed.

### Organizing Concerns

Use **sub-model concerns** for domain logic specific to one model:

```
app/models/
├── member.rb
└── member/
    ├── billable.rb       # Member-specific billing logic
    └── deliverable.rb    # Member-specific delivery logic
```

```ruby
# app/models/member/billable.rb
module Member::Billable
  extend ActiveSupport::Concern

  included do
    scope :billable, -> { where(billing_enabled: true) }
  end

  def bill!
    # Billing logic here
  end
end

# In the model, no need to namespace the include:
class Member < ApplicationRecord
  include Billable  # Not Member::Billable
end
```

Tests for sub-model concerns should also be in separate files mirroring the structure:

```
test/models/
├── member_test.rb
└── member/
    ├── billable_test.rb
    └── deliverable_test.rb
```

Use **shared concerns** in `app/models/concerns/` for behavior used across multiple models:

```ruby
# app/models/concerns/archivable.rb
module Archivable
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(archived_at: nil) }
    scope :active, -> { where(archived_at: nil) }
  end

  def archive
    update!(archived_at: Time.current)
  end
end
```

A good concern:
- Groups related methods, scopes, and callbacks together
- Is cohesive - everything relates to one concept
- Can be understood in isolation
- Has a clear, descriptive name

### Model & Class Structure

Order elements within a model class consistently:

```ruby
class Member < ApplicationRecord
  # 1. Includes and extends
  include Billable, Deliverable

  # 2. Constants
  STATUSES = %w[pending active inactive].freeze

  # 3. Attribute macros
  enum :status, STATUSES.index_by(&:itself), default: :pending

  # 4. Associations (belongs_to first, then has_*)
  belongs_to :organization
  has_many :baskets, dependent: :destroy
  has_one :subscription

  # 5. Validations
  validates :email, presence: true

  # 6. Callbacks (in lifecycle order)
  before_create :set_defaults
  after_create :send_welcome_email

  # 7. Scopes
  scope :active, -> { where(status: :active) }

  # 8. Class methods
  def self.search(query)
    where("name LIKE ?", "%#{query}%")
  end

  # 9. Public instance methods
  def display_name
    "#{first_name} #{last_name}"
  end

  # 10. Private methods
  private

  def set_defaults
    self.language ||= Current.org.default_language
  end
end
```

For POROs, follow a similar structure: class methods, `initialize`, public methods, then private methods.

## Testing Guidelines

- Run only the specific tests relevant to your changes
- Test files mirror the `app/` directory structure in `test/`
- Use fixtures for test data
- System tests use Capybara (with Rack::Test)

## Security

- Never hardcode API keys, secrets, or credentials
- Use environment variables via `dotenv` for local development
- Brakeman runs for security scanning

## Documenting Complex Classes

When creating non-trivial classes, add a comment block at the top explaining:
- **Why** the class exists
- **What** problem it solves
- **How** it's intended to be used

## Commit Messages

- Review all staged changes before writing
- Keep it short, prefer a few sentences over long bullet points
- Explain **why** the change is needed, not just what changed

## Quick Reference

| Topic | Tool/Approach |
|-------|---------------|
| Authorization | CanCanCan abilities |
| Admin UI | ActiveAdmin |
| Background Jobs | Solid Queue |
| Monitoring | AppSignal |
| Email | Postmark |
