<a href="https://csa-admin.org">
  <img title="CSA/ACP/Solawi Admin logo" src="https://csa-admin.org/images/logo-23671d2e.svg" width="100">
</a>

# CSA/ACP/Solawi Admin

[![CI](https://github.com/csa-admin-org/csa-admin/actions/workflows/ci.yml/badge.svg)](https://github.com/csa-admin-org/csa-admin/actions/workflows/ci.yml)
[![Security](https://github.com/csa-admin-org/csa-admin/actions/workflows/security.yml/badge.svg)](https://github.com/csa-admin-org/csa-admin/actions/workflows/security.yml)
[![Ruby](https://img.shields.io/badge/dynamic/toml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fcsa-admin-org%2Fcsa-admin%2Fmaster%2Fmise.toml&query=%24.tools.ruby&label=Ruby&color=CC342D&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Ruby on Rails](https://img.shields.io/badge/Ruby_on_Rails-CC0000?logo=ruby-on-rails&logoColor=white)](https://rubyonrails.org/)

CSA/ACP/Solawi Admin is a web application to manage Community Supported Agriculture organizations:
- **CSA** (Community Supported Agriculture)
- **ACP** (Agriculture Contractuelle de Proximité)
- **Solawi** (Solidarische Landwirtschaft)

Learn more on [csa-admin.org](https://csa-admin.org).

## Features

- Member management (status, contact information, etc.)
- Membership management (basket size, depot location, quantity, delivery cycle, etc.)
- Basket complements (delivery frequency, quantity, etc.)
- Online grocery store for additional product orders
- Advanced delivery cycle management (every two weeks, winter/summer, etc.)
- Basket content management (harvest-based quantity calculations, price monitoring, etc.)
- Bidding rounds for solidarity-based basket pricing (member pledges with min/max bounds)
- Automatic invoicing:
  - memberships
  - membership shares / annual fees
  - invoice dispatch with QR code and SEPA reference numbers
  - automatic payment statement import from bank accounts (EBICS 3.0/H005/BTF, BAS, bunq)
  - overdue notices
- Activity participation management with member registration forms
- Transactional email and built-in newsletter system
- Multilingual support (**en, fr, de, it, nl**)

Need a demo or a specific feature? [Contact me](mailto:info@csa-admin.org).

## Organizations

This application is currently used by [more than 30 organizations](https://csa-admin.org/#organizations) in Switzerland, Germany, and the Netherlands, and manages more than 140,000 basket deliveries per year.

## Technical overview

- Built with Ruby on Rails
- Multi-tenant architecture:
  - tenant resolved from the configured request host
  - one isolated SQLite database per tenant
- Asynchronous jobs handled by Solid Queue and Active Job (SQLite-backed)
- Transactional emails and newsletters sent via Postmark
- Tenant-local bank connections for automatic payment imports and EBICS 3.0/H005/BTF uploads; see `docs/bank_connections.md` for manual console setup

## Getting started

Development requirements are managed with [Mise](https://mise.jdx.dev) 2026.7 or newer. Local development uses [puma-dev](https://github.com/puma/puma-dev) over HTTPS.

1. Clone the repository.
2. Install and activate Mise, then install and configure puma-dev for your system.
3. Trust the project configuration and bootstrap the application:

   ```sh
   mise trust
   mise bootstrap
   ```

   This installs libvips and Poppler, the Ruby, Node, and Aube versions declared in `mise.toml`, then runs `bin/setup --skip-server`. On Intel macOS, install libvips and Poppler through Homebrew first because Mise's Brew bootstrap supports Apple Silicon only.

4. Update the generated `config/tenant.yml` with your admin and member hostnames.
5. From the repository directory, link the configured base domain to puma-dev. For the sample `my-domain.org` configuration:

   ```sh
   puma-dev link -n my-domain
   ```

6. Open the configured `admin_host` or `members_host`, replacing its public top-level domain with `.test`. For example:
   - `admin.ragedevert.ch` → [admin.ragedevert.test](https://admin.ragedevert.test)
   - `membres.ragedevert.ch` → [membres.ragedevert.test](https://membres.ragedevert.test)

   Use the configured host rather than deriving it from the tenant name: host labels and domains vary between organizations. Admin and member portals have separate authentication contexts. The `acme` tenant is test-only and is not available for local browser access.

7. Sign in through the selected tenant's local admin host with an admin email for that tenant.

## Development

Useful commands:

- Run all tests: `bin/rails test:all`
- Run final validation (setup, style, security, tests, seeds): `bin/ci`
- Individual linters/formatters remain available (`bin/rubocop`, `bin/syntax`, `bin/herb`, …)

## Contributing

Contributions are welcome.

Before starting substantial work (new feature, larger refactor), please [contact me](mailto:info@csa-admin.org) first so we can align on scope and implementation.

For smaller fixes and improvements, feel free to open a pull request.

## Support

- Thibaud Guillaume-Gentil ([info@csa-admin.org](mailto:info@csa-admin.org))

For demos, support, or custom feature requests, [contact me](mailto:info@csa-admin.org).

## License

CSA/ACP/Solawi Admin is released under the [O’Saasy License](https://osaasy.dev).
