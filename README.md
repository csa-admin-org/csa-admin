<a href="https://csa-admin.org">
  <img title="CSA/ACP/Solawi Admin logo" src="https://csa-admin.org/images/logo-23671d2e.svg" width="100">
</a>

# CSA/ACP/Solawi Admin

[![Tests](https://github.com/csa-admin-org/csa-admin/actions/workflows/tests.yml/badge.svg)](https://github.com/csa-admin-org/csa-admin/actions/workflows/tests.yml) [![Security](https://github.com/csa-admin-org/csa-admin/actions/workflows/security.yml/badge.svg)](https://github.com/csa-admin-org/csa-admin/actions/workflows/security.yml)

CSA/ACP/Solawi Admin is a web application to manage Community Supported Agriculture organizations:
- **CSA** (Community Supported Agriculture)
- **ACP** (Agriculture Contractuelle de Proximité)
- **Solawi** (Solidarische Landwirtschaft)

Learn more on [csa-admin.org](https://csa-admin.org).

## Features

- Member management (status, contact information, etc.)
- Membership management (basket size type, depot location, quantity, deliveries, etc.)
- Basket complements (delivery frequency, quantity, etc.)
- Online grocery store for additional product orders
- Advanced delivery cycle management (every two weeks, winter/summer, etc.)
- Basket content management (harvest-based quantity calculations, price monitoring, etc.)
- Bidding rounds for solidarity-based basket pricing (member pledges with min/max bounds)
- Automatic invoicing:
  - memberships
  - membership shares / annual fees
  - invoice dispatch with reference numbers (QR-Code, SEPA)
  - automatic payment statement import from bank account (EBICS)
  - overdue notices
- Activity participation management with member registration forms
- Advanced email and built-in newsletters system
- Multi-language support (**en, fr, de, it, nl**)

Need a demo or a specific feature? [Contact me](mailto:info@csa-admin.org).

## Organizations

This application is currently used by [more than 30 organizations](https://csa-admin.org/#organizations) in Switzerland, Germany, and the Netherlands, and manages more than 140,000 basket deliveries per year.

## Technical overview

- Built with Ruby on Rails
- Multi-tenant architecture:
  - tenant resolved from request subdomain
  - one isolated SQLite database per tenant
- Asynchronous jobs handled by SolidQueue/ActiveJob (SQLite-backed)
- Transactional emails and newsletters sent via Postmark

## Getting started

1. Clone the repository
2. Copy `config/tenant.yml.example` to `config/tenant.yml` and update your admin/member hostnames
3. Install dependencies, prepare and seed databases:

   `bin/setup`

4. Set up local subdomains (recommended: [puma-dev](https://github.com/puma/puma-dev)) to access:
   - [admin.my-domain.test](https://admin.my-domain.test)
   - [members.my-domain.test](https://members.my-domain.test)

5. Sign in to [the admin](https://admin.my-domain.test) with your email (for example `admin@my-domain.test`)

## Development

Useful commands:

- Run all tests: `bin/rails test:all`
- Check linting: `bin/rails lint:check`
- Auto-fix linting issues: `bin/rails lint:autocorrect`

## Contributing

Contributions are welcome.

Before starting substantial work (new feature, larger refactor), please [contact me](mailto:info@csa-admin.org) first so we can align on scope and implementation.

For smaller fixes and improvements, feel free to open a pull request.

## Support

- Thibaud Guillaume-Gentil ([info@csa-admin.org](mailto:info@csa-admin.org))

For demos, support, or custom feature requests, [contact me](mailto:info@csa-admin.org).

## License

CSA/ACP/Solawi Admin is released under the [O’Saasy License](https://osaasy.dev).
