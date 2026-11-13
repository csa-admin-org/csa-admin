# Glossary

## Domain Terms

- **CSA**: Community Supported Agriculture — a model where members subscribe to receive regular deliveries of farm produce.
- **Tenant**: An isolated organization instance. Each tenant has its own SQLite database, resolved from the request subdomain.
- **Query API**: Read-only SQL on `query.csa-admin.org` for operator/support. Credentials `query`, not `Organization#api_token`. Path includes `:tenant`; the controller switches. `SELECT` / schema / models / `EXPLAIN QUERY PLAN` / blob download. Fleet walk (no path tenant): `POST /tickets/search`, `GET /organizations`, `GET /bank_connections`. Cloud: `query-api` skill (HTTPS). This machine: `query-cli` (`bin/query`). No Ruby eval. Encrypted columns come back as ciphertext on SQL; fleet org/bank envelopes omit them. `sqlite_*` / `pragma_*` / `_litestream_*` denied. People rows allowed. See `.agents/tasks/done/2026/09/query-api.md`.
- **Support thread**: Lives on that tenant (`support_tickets` / `support_messages`), not a laptop JSONL. Search and draft: `support` skill. Voice: `.agents/skills/support/voice.md`. Live facts still go through Query API.
- **Global API**: Parked redacted JSON hub (`Global::V1` on `api.csa-admin.org`). Replaced by Query API. Never shipped; local `global-api` branch deleted. See `.agents/tasks/done/2026/09/csa-admin-cli.md`.
- **Local tenant dump**: Development SQLite restored from the daily Litestream rclone (`bin/rails development:restore`). Feature work on this machine. Not a support API. See the `local-tenants` skill.
- **Org / Organization**: The singleton settings record for the current tenant (`Current.org`). Prefer **organization**, **org**, or **tenant** over **farm** in commits, PRs, and task docs. Not every tenant is a farm. Keep **farm** for produce or a tenant name.
- **Fiscal Year (FY)**: The organization's accounting year, which may start in any month (not necessarily January).

## Models

- **Delivery** (`app/models/delivery.rb`): A scheduled delivery date. Multiple deliveries can exist in the same calendar week (e.g., Monday + Thursday via different delivery cycles).
- **DeliveryCycle** (`app/models/delivery_cycle.rb`): Defines a recurring delivery pattern (e.g., "every Monday", "every Thursday", "both"). Members subscribe to a cycle.
- **Basket** (`app/models/basket.rb`): A single basket instance for a member on a specific delivery. Linked to a `BasketSize` and `Depot`.
- **BasketSize** (`app/models/basket_size.rb`): A tier of basket (e.g., Small, Medium, Large) with a base price. `paid` scope excludes the zero-price "complements only" size.
- **BasketContent** (`app/models/basket_content.rb`): A product distribution record for a specific delivery. Defines how a product's total quantity is split across basket sizes. Belongs to a single `Delivery`.
- **BasketContent::Product** (`app/models/basket_content/product.rb`): A product that can appear in basket contents (e.g., carrots, cucumbers).
- **BasketComplement** (`app/models/basket_complement.rb`): An add-on product (e.g., bread, eggs) that members can subscribe to alongside their basket.
- **Depot** (`app/models/depot.rb`): A pickup location where members collect their baskets.
- **Membership** (`app/models/membership.rb`): A member's subscription for a fiscal year, linking them to a basket size, delivery cycle, depot, and optional complements.
- **Member** (`app/models/member.rb`): A person or household subscribed to the CSA.
- **HomeDeliveryAddress** (`app/models/home_delivery_address.rb`): Delivery-grained overlay for a home-delivery drop at someone else's. Lookup is `for(member, delivery)`. Does not change member identity, invoices, or the portal address.
- **Producer** (`app/models/producer.rb`): Optional shared producer for shop products and basket content products. One list, under Other, shown when shop or basket content is enabled. Not `BasketContent::Producer` and not `Shop::Producer`. `NullProducer` is only the member-shop "producer not defined" filter sentinel.
- **Shop**: Optional members store (`Shop::Product`, orders, special deliveries). Copy names: EN Shop, FR **Épicerie** (never *boutique*), DE Hofladen, IT Bottega, NL Winkel. See `TRANSLATIONS.md`. Grouped invoicing: `organizations.shop_invoice_period` is the default (`nil` = each order); `members.shop_invoice_period` overrides it. A nil member column follows the organization, it is not copied.
- **Newsletter::Publication** (`app/models/newsletter/publication.rb`): Immutable public snapshot of selected editorial blocks from a sent newsletter, exposed via the optional members-host Atom feed (`GET /newsletters.atom?template_id=`). Payload is multi-locale (`locale` query param; default language otherwise). Opt-in per template via `feed_enabled` and `{% content public: true %}`.

## Key Concepts

- **Basket i18n Scope**: A per-organization setting (`organizations.basket_i18n_scope`) that controls the terminology used for "basket" throughout the app. Possible scopes: `basket`, `bag`, `share`, `package`, `cone`, `crate`. Each scope provides distinct translations in all 5 languages. Modeled after `activity_i18n_scope`. Helpers: `BasketsHelper#basket_human_name`, `baskets_human_name`, `basket_content_human_name`, `basket_size_human_name`, `basket_complement_human_name`, `t_basket`, `basket_scoped_attribute`.

- **Activity i18n Scope**: A per-organization setting (`organizations.activity_i18n_scope`) that controls the terminology for required member work. Possible scopes: `hour_work`, `halfday_work`, `day_work`, `basket_preparation`.

- **Included absences**: A membership discount. `absences_included_annually` is the full-year input (cycle default, optional membership override). `absences_included` is the computed quota, today a basket/full-year ratio, about to become org Liquid (`absences_included_logic`). Leftover quota marks the last baskets provisionally absent.
- **ISO Calendar Week (cweek/cwyear)**: Week numbering per ISO 8601. Used to group deliveries within the same week. Monday is day 1.
- **Unfilled Delivery**: A delivery that has no `BasketContent` records yet.
- **Same-week Deliveries**: Other deliveries sharing the same ISO calendar week as a given delivery.
- **Duplicate All**: Copying basket content products missing from a target delivery while preserving their unit, unit price, basket quantities, and depots.

- **Cap**: The current bot barrier for unauthenticated forms (member registration, member login, admin login, demo registration). CSA Admin self-hosts Cap Standalone at `https://cap.csa-admin.org`; each tenant stores its own `cap_site_key` and encrypted `cap_secret_key` on `organizations`.

- **Demo Page Visit** (`Demo::PageVisit`): A demo-tenant-only record of an authenticated admin-side HTML page load. Meaningful visits are classified live from `page_key`, so the non-meaningful page list can be adjusted without rewriting stored visits.

## Banking / Payments

- **BankConnection** (`app/models/bank_connection.rb`): Tenant-local payment provider configuration. Active payment imports resolve through `bank_connections`, not legacy `organizations` columns.
- **EBICS**: Electronic Banking Internet Communication Standard — bank communication protocol used by some CSA Admin tenants for automatic payment file downloads and, in some cases, payment/direct-debit uploads. CSA Admin supports EBICS 3.0 / H005 / BTF only for active runtime and new connections.
- **EBICS H003/H004/H005**: EBICS protocol version markers. H003 roughly maps to EBICS 2.4, H004 to EBICS 2.5, and H005 to EBICS 3.0. H003/H004 are historical migration context only and are no longer supported runtime paths in CSA Admin.
- **BTF**: Business Transaction Format — EBICS 3.0 mechanism that identifies bank business operations with structured parameters instead of only country-specific legacy order types.
- **BTD / BTU**: EBICS 3.0 banking order types. `BTD` downloads files from the bank; `BTU` uploads files to the bank.
- **INI / HIA / HPB**: EBICS subscriber setup order types. `INI` initializes the electronic signature key, `HIA` initializes authentication/encryption keys, and `HPB` fetches bank public keys after the bank activates the subscriber.
- **CAMT**: ISO 20022 cash-management XML messages. CSA Admin parses `camt.053` and `camt.054` for payment matching.
- **PAIN**: ISO 20022 payment-initiation XML messages. CSA Admin generates `pain.008.001.08` for SEPA direct debit.

## Abbreviations

- **FY**: Fiscal Year
- **BC**: Basket Content
- **BS**: Basket Size
- **Promotion** (`Promotion`): A printed registration link and QR, not a typed code. Public name is Promotion / Promotion / Aktion / Promozione / Actie. The token is 12 lowercase hex, generated once, immutable. Active or archived. A past `ends_on` is refused; `Scheduled::PromotionsArchiverJob` archives it the night after. A fixed discount on one membership, written into `membership.price`. Not a price reduction. A later member link is the same instrument. A later referrer credit is not a promotion.
- **Promotion claim** (`PromotionClaim`): The claim, one live per member. Snapshots the amount and the title the member saw. Applied when the membership is created. Voided only if that membership ends during the trial and commitment is required. Expires one year after the claim. A later edit of the promotion does not rewrite it.
- **Analytics**: Admin page of live fiscal-year aggregates (memberships, size mix, prices, invoices, time-to-pay). Not the operational dashboard and not a warehouse.
