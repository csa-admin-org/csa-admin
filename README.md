<a href="https://csa-admin.org">
  <img title="CSA/ACP/Solawi Admin logo" src="https://csa-admin.org/images/logo-23671d2e.svg" width="100">
</a>

# CSA/ACP/Solawi Admin

[![Tests](https://github.com/csa-admin-org/csa-admin/actions/workflows/tests.yml/badge.svg)](https://github.com/csa-admin-org/csa-admin/actions/workflows/tests.yml) [![Security](https://github.com/csa-admin-org/csa-admin/actions/workflows/security.yml/badge.svg)](https://github.com/csa-admin-org/csa-admin/actions/workflows/security.yml)

Web application to manage CSA (Community Supported Agriculture), ACP (Agriculture Contractuelle de Proximité), or Solawi (Solidarische Landwirtschaft) organizations.

Learn more on [csa-admin.org](https://csa-admin.org).

## Features

Functions currently supported include:

- Member management (status, contact information, etc.)
- Membership management (basket size type, depot location, quantity, deliveries, etc.)
- Basket complements (delivery frequency, quantity, etc.)
- Online grocery store to allow members to order additional products
- Advanced delivery cycle management (every two weeks, winter/summer, etc.)
- Basket content management (calculation of quantities according to harvests, price monitoring, etc.)
- Automatic invoicing of memberships, creation and dispatch of invoices with reference numbers (QR-Code), automatic payment statements import from bank account (EBICS), overdue notice, etc.
- Automatic invoicing of membership shares or annual fees
- Activity participation management, with registration form for your members
- Advanced email and built-in newsletters system
- Multi-language support (English/French/German/Italian)
- And more... please [contact me](mailto:info@csa-admin.org) for a demo.

Other features can be added as required, please [contact me](mailto:info@csa-admin.org) for more information.

## Organizations

This application is currently used by [more than 30 organizations](https://csa-admin.org/#organizations) in Switzerland and Germany, and manages more than 100,000 basket deliveries per year.

## Technical details

- This application is built with Ruby on Rails and uses SQLite as databases.
- Asynchronous jobs are handled by SolidQueue/ActiveJob and are backed by SQLite.
- Transactional emails and newsletters are sent using the Postmark service.

## Development and support

- Thibaud Guillaume-Gentil ([info@csa-admin.org](mailto:info@csa-admin.org))

Don't hesitate to [contact me](mailto:info@csa-admin.org) for a demo or more information.

## Contributing

I'm encouraging you to contribute to this project. Please [contact me](mailto:info@csa-admin.org) before starting to work on a feature or a bug fix.

## License

CSA/ACP/Solawi Admin is released under the [MIT License](https://opensource.org/licenses/MIT).
