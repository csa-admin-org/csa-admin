---
name: query
description: >
  Live read-only Query API via `bin/query` (prod or query.csa-admin.test).
  Tenant SQL/schema/blobs, fleet orgs/banks, and support-ticket search.
  Minimize PII in SELECT and in chat unless explicitly needed. Not for
  writes, Organization#api_token, Kamal, or Litestream dumps.
---

# Query

Read-only access to live tenant data through `bin/query`. Same host for
local Mac, Cloud Agents, and self-hosted workers when
`CSA_ADMIN_API_TOKEN` is set.

Not tenant `/api/v1`. Not Kamal. Not `rails query`. Not restored Litestream
dumps (local feature work only).

## PII

Default: **skip** personal and other sensitive data. Prefer ids, states,
amounts, dates, counts, and feature flags.

Treat columns matching
`config/initializers/filter_parameter_logging.rb` as sensitive (partial
name match: `email`, `phone`, `street`, `city`, `zip`, `name`, `iban`,
`body`, `note`, `token`, `passw`, `credentials`, …). Do not `SELECT` or
paste them into chat unless the user explicitly asks or the task cannot
proceed without that field.

Narrow column lists — never `SELECT *` on `members`, addresses, or payment
tables. If a row must be confirmed, use `id` / `display_id` / state first.
Fleet org/bank envelopes already omit email, IBAN, tokens, and credentials;
do not re-fetch those via SQL “to be thorough.”

## Setup

```bash
bin/query -h
```

Prints `CSA_ADMIN_API_URL` (default `https://query.csa-admin.org`) and
whether `CSA_ADMIN_API_TOKEN` is set. Local override is often
`https://query.csa-admin.test`. Never print the token. Never put
`Organization#api_token` in `CSA_ADMIN_API_TOKEN`.

If `-h` is stale versus this skill, trust `-h` for commands and this file
for guardrails. Discover routes from `bin/query /` when needed.

## Fleet (no `/:tenant` in the path)

Walk allowed live tenants in one request. Skip demo/custom. `--tenant` is
a slug or list, not the path — it intersects the token allowlist.

Use these to target (`who has EBICS / provisional absences?`) then
one-tenant SQL for facts. Do not loop `/:tenant/sql` yourself.

```bash
bin/query /
bin/query /organizations --attributes absences_included_mode,features
bin/query /organizations --absences_included_mode provisional_absence
bin/query /bank_connections --provider ebics --state ready
bin/query /tickets/search --q absences --per 20
bin/query /tickets/search --q EBICS --tenant TENANT,TENANT2
```

`tickets[]` include `snippet` (~80 chars around `q`, emails redacted). Use
it to drop false `LIKE` hits, then load **one** thread with tenant SQL.
Subjects `Test` / `test 2` are noise.

## One tenant (path `/:tenant`)

After handbook and code, prefer ids from ticket context
(`/memberships/12`, `/invoices/310`, `/members/42`). SQL envelope
`{ columns, rows, meta }`. Encrypted columns (org tokens, Postmark, CAP,
bank credentials) come back as ciphertext — do not try to decrypt. The API
allows people rows and mail bodies; still apply **PII** above.

Never `GET ?sql=` / `GET ?q=` — `bin/query` already POSTs where required.
Replace `:tenant` with the real slug.

```bash
bin/query /:tenant/schema
bin/query /:tenant/schema/invoices
bin/query /:tenant/models
bin/query /:tenant/sql --sql 'SELECT id, state FROM invoices WHERE id = 310'
bin/query /:tenant/explain --sql 'SELECT * FROM baskets WHERE membership_id = 12'
bin/query /:tenant/blobs/42 > invoice.pdf
```

Denied tables (400 if named): `sqlite_*`, `pragma_*`, `_litestream_*`.
Max 500 rows per SQL page.

Invoice PDF (or SEPA mandate, org logo): SQL
`active_storage_attachments` + `active_storage_blobs`, then
`bin/query /:tenant/blobs/:id` (file bytes, not JSON). Blobs can contain
PII — fetch only when needed; do not dump them into chat.

## Do not

- Write, mutate, or call Kamal / tenant `/api/v1` / `rails query`.
- Use a restored dump instead of this for a live ticket.
- Widen SELECTs or paste PII “just in case” (see **PII**).
- Print or log `CSA_ADMIN_API_TOKEN`.
