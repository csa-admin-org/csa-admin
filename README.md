<a href="https://acp-admin.ch">
  <img title="CSA/ACP/Solawi Admin logo" src="https://acp-admin.ch/images/logo-23671d2e.svg" width="100">
</a>

# ACP/CSA/Solawi Admin

[![Tests](https://github.com/acp-admin/acp-admin/actions/workflows/tests.yml/badge.svg)](https://github.com/acp-admin/acp-admin/actions/workflows/tests.yml) [![Brakeman Scan](https://github.com/acp-admin/acp-admin/actions/workflows/brakeman.yml/badge.svg)](https://github.com/acp-admin/acp-admin/actions/workflows/brakeman.yml)

Web application to manage CSA (Community Supported Agriculture), ACP (Agriculture Contractuelle de Proximité) or Solawi (Solidarische Landwirtschaft) organizations.

Learn more on [acp-admin.ch](https://acp-admin.ch).

## Features

Functions currently supported include

- Member management (status, contact information, etc.)
- Subscription management (basket size type, depot location, quantity, deliveries, etc.)
- Basket complements (delivery frequency, quantity, etc.)
- Online grocery store to allow members to order additional products
- Advanced delivery cycle management (every two weeks, winter/summer, etc.)
- Basket content management (calculation of quantities according to harvests, price monitoring, etc.)
- Automatic invoicing of subscriptions, creation and dispatch of invoices with reference number (QR-Code), automatic payment statements import from Bank account (EBICS), overdue notice, etc.
- Automatic invoicing of membership shares or annual fees
- Activity participations management, with registration form for your member
- Advanced e-mail and built-in newsletters system
- Multi-language support (French/German/Italian)
- And more... please [contact me](mailto:info@acp-admin.ch) for a demo.

Other features can be added as required, please [contact me](mailto:info@acp-admin.ch) for more information.

## Organizations

This application is currently used by [more than 25 organizations](https://acp-admin.ch/#acps) in Switzerland and Germany, and manage more than 100'000 basket deliveries per year.

## Technical details

- This application is built with Ruby on Rails and uses PostgreSQL as database.
- Asynchronous jobs are handled by Sidekiq/ActiveJob and are backed by Redis.
- Transactional emails and newsletters are sent using Postmark service.

## Development and support

- Thibaud Guillaume-Gentil ([info@acp-admin.ch](mailto:info@acp-admin.ch))

Don't hesitate to [contact me](mailto:info@acp-admin.ch) for a demo or more information.

## Contributing

I'm encouraging you to contribute to this project. Please [contact me](mailto:info@acp-admin.ch) before starting to work on a feature or a bug fix.

## License

ACP/CSA/Solawi Admin is released under the [MIT License](https://opensource.org/licenses/MIT).
