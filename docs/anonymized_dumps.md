# Anonymized tenant dumps

Scaffold for a nightly job that restores each production tenant SQLite database from its Litestream replica, strips personal data, and publishes the result to a separate Backblaze B2 bucket. A Cursor cloud agent can then download one or more of those databases and work on real-shaped data. Demo tenants stay the default. Invoice PDFs and other Active Storage files are not copied. PDFs are generated in dev and test.

This branch does not call Litestream, B2, or production. Replica restore and bucket upload raise `NotImplementedError` until credentials exist. The anonymizer, the column classification, the fail-closed schema test, and the agent download task run locally.

`lib/tasks/masker.rake` is a different tool. It is a non-deterministic, partial mask for a developer's already-restored databases. The nightly dump should use `anonymized_dump:anonymize`, not `masker:run`.

## 1. Litestream

Production replication is configured by `LitestreamConfig.server` and pushed to the host by `litestream:config:server`. It is not a Kamal accessory. `config/deploy.yml` accessories are only `cap` and `cap-valkey`. The pre-deploy hook migrates. The Dockerfile does not install Litestream. The binary runs as `litestream.service` on the host (`/etc/litestream.yml`, root). The host is shared: `merge_host_config` keeps database entries whose path is outside `/storage/csa-admin`.

The generated config is Litestream v0.5, not v0.3:

- One `replica` key per database. The v0.3 `replicas` array is not emitted.
- Replica type `s3`, bucket `csa-admin-litestream`, replica path = tenant name (and `queue` for the job database).
- Database path `/storage/csa-admin/production_<tenant>.sqlite3`.
- `sync-interval` 1h. `snapshot.interval` 24h. `snapshot.retention` 72h.
- LTX layout. On S3 that is `<path>/0000/*.ltx` and `<path>/0009/*.ltx`. The dev restore materializes that into the file layout `ltx/<level>/`.

v0.5 removed Age encryption. A replica written by v0.3 with Age cannot be restored by v0.5. v0.5.7 and later detect v0.3 WAL generations versus LTX and restore whichever is newer. This repo's generated config has no Age key and the local restore tests the LTX layout, so production is on v0.5 LTX. Pin the job's binary to the same minor version as the host. The repo does not record that version.

### Restore without touching the primary

`litestream restore` reads the replica and writes a new SQLite file. It does not open the running primary, as long as `-o` is a scratch path. If `-o` is omitted, restore writes to the `path` in the config, which in production is the live database. The job must always pass `-o` and must not mount `/storage/csa-admin` read-write.

A one-database config is enough. The positional argument is the configured `path`:

```yaml
dbs:
  - path: /tmp/logical/production_ragedevert.sqlite3
    replica:
      type: s3
      bucket: csa-admin-litestream
      path: ragedevert
      endpoint: https://s3.<region>.backblazeb2.com
      access-key-id: ${LITESTREAM_ACCESS_KEY_ID}
      secret-access-key: ${LITESTREAM_SECRET_ACCESS_KEY}
```

```sh
litestream restore \
  -config /tmp/litestream.yml \
  -o /tmp/anonymized/ragedevert.sqlite3 \
  -timestamp 2026-11-12T02:00:00Z \
  /tmp/logical/production_ragedevert.sqlite3
```

`-timestamp` is exclusive: an LTX file is applied only when it was created strictly before that time. Restore lands on LTX file boundaries, not on every transaction. With the default compaction levels (30s, 5m, 1h) and `l0-retention` of 5 minutes, fine-grained points disappear quickly. Snapshot retention is 72 hours, so the restorable window is about three days, not a long archive. `sync-interval` is 1h, so the replica can lag the primary by up to an hour. For a nightly dump, `-timestamp` at job start is enough. `-integrity-check quick` is available on v0.5.10 and later. Do not use `-f` follow mode.

Skip the `queue` replica. Job arguments contain member data, mail, and banking payloads. `LitestreamConfig.server` replicates it (`Tenant.all + ["queue"]`). The anonymized bucket must not.

### Cost and time

Not measured. No production credentials were used, and file sizes are unknown.

Public B2 rates are about $6/TB-month for storage, free egress up to 3× the average stored bytes, then $0.01/GB, and $0.004 per 10,000 class B (download) calls. Compaction means a latest restore downloads about one snapshot plus recent increments, on the order of the live SQLite file, not the historical WAL. Snapshot retention is only 72h, so the replica bucket is a few copies of the live set rather than years of history.

If the sum of tenant databases is S gigabytes, a nightly download is about 30S GB/month. That can exceed the free egress allowance, because 30× the live size is larger than 3× a 72-hour replica. At $0.01/GB the bill stays small even if S is tens of gigabytes. Class B calls are a handful of LTX files per tenant. The anonymized bucket then stores gzipped copies. SQLite gzips well. Thirty dated copies plus `latest` is the proposed retention.

Time is network-bound. A few hundred megabytes is typically under a minute per tenant from a nearby region. Parallelism of about four keeps a nightly run well inside an hour for the current tenant count. Confirm with `litestream restore -dry-run` once a read-only key exists. That flag needs v0.5.12 or later.

### Where it should run

Not on the app host, and not as a Kamal accessory with the storage volume mounted. A bad `-o` there overwrites production, and the app container holds the production `RAILS_MASTER_KEY`. The anonymizer must not boot with that key. It overwrites encrypted columns with ciphertext from the development key that cloud agents already use, and it never decrypts the production values. Running inside the production process makes a bug able to write anonymized rows back to the primary.

Use a separate small VM or a private scheduled GitHub Action:

- Read-only key on `csa-admin-litestream` only.
- Write key on the new bucket only. The two keys must not be interchangeable.
- Development `RAILS_MASTER_KEY` (or the same `secret_key_base` agents boot with), not the production key.
- No mount of `/storage/csa-admin`.
- Scratch disk under `/tmp`.

A GitHub Action checks out this repo, installs the Litestream binary and Ruby, restores to scratch, runs the anonymizer, gzips, and uploads. A tiny VM is the same shape with a cron and a longer disk. Prefer either of those over cron on `isle.thibaud.gg`.

## 2. How tenants are stored

Each tenant is one SQLite file. The request host selects the tenant (`Tenant.find_by`). There is no `org_id` column and no shared tenant schema. `config/tenant.yml` lists tenants per Rails env. Development reuses the production list. Test has `acme` and `beta` only.

`config/database.yml` defines one shard per tenant: `storage/<env>_<tenant>.sqlite3`, migrations in `db/migrate`. `Tenant.switch` connects that shard. Do not query tenant models outside a switch, and do not carry records across tenants.

`config/tenant.yml` production has 45 entries:

- 39 default `production` (the ones to dump, once Thibaud confirms the list).
- 2 `onboarding`: `pluk`, `zalpenblick`.
- 4 `custom`: `demo-fr`, `demo-en`, `demo-de`, and `microfermes`.

Demo databases are `demo-en`, `demo-fr`, and `demo-de`. They are seeded, not restored from this bucket. `Restore` refuses those names.

There is no global SQL database. Cache is `memory_store` (namespace = current tenant). Cable is Redis. Production jobs are Solid Queue on a separate file, `storage/production_queue.sqlite3`, migrated from `db/queue_schema.rb` and replicated under the replica path `queue`. That file's tables are `solid_queue_blocked_executions`, `solid_queue_claimed_executions`, `solid_queue_failed_executions`, `solid_queue_jobs`, `solid_queue_pauses`, `solid_queue_processes`, `solid_queue_ready_executions`, `solid_queue_recurring_executions`, `solid_queue_recurring_tasks`, `solid_queue_scheduled_executions`, `solid_queue_batches`, `solid_queue_batch_executions`, and `solid_queue_semaphores`. Do not publish it.

Active Storage metadata (`active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`) lives in the tenant database. Bytes live in the `csa-admin-storage` bucket under a tenant prefix (`tenant_object_store` in production, disk in development). The dump deletes the metadata tables, so production object keys and signed ids are not in the file. Newsletter HTML that embedded those URLs is rewritten. Invoice and SEPA PDFs, logos, and billing snapshot files are absent. Generate them in dev.

The tenant schema is `db/schema.rb` (78 tables, including the FTS5 table `search_entries`). Litestream also creates `_litestream_lock` and `_litestream_seq` at runtime. The schema dumper ignores them. Leave them in the restored file. They are not personal data.

Tables: `absences`, `action_text_rich_texts`, `active_admin_comments`, `active_storage_attachments`, `active_storage_blobs`, `active_storage_variant_records`, `activities`, `activity_participations`, `activity_presets`, `admins`, `announcements`, `attachments`, `audits`, `bank_connection_finalization_notifications`, `bank_connections`, `basket_complements`, `basket_complements_deliveries`, `basket_content_products`, `basket_contents`, `basket_contents_depots`, `basket_overrides`, `basket_shifts`, `basket_sizes`, `baskets`, `baskets_basket_complements`, `bidding_round_pledges`, `bidding_rounds`, `billing_snapshots`, `deliveries`, `delivery_cycle_periods`, `delivery_cycles`, `delivery_cycles_depots`, `demo_page_visits`, `depot_groups`, `depots`, `email_suppressions`, `forced_deliveries`, `home_delivery_address_deliveries`, `home_delivery_addresses`, `invoice_items`, `invoices`, `mail_deliveries`, `mail_delivery_emails`, `mail_templates`, `member_cards`, `members`, `members_basket_complements`, `members_waiting_alternative_depots`, `membership_price_reductions`, `memberships`, `memberships_basket_complements`, `newsletter_blocks`, `newsletter_publications`, `newsletter_segments`, `newsletter_templates`, `newsletters`, `organizations`, `payments`, `permissions`, `price_reduction_cards`, `price_reductions`, `producers`, `promotion_claims`, `promotions`, `sepa_mandates`, `sessions`, `shop_order_groups`, `shop_order_items`, `shop_orders`, `shop_product_variants`, `shop_products`, `shop_products_special_deliveries`, `shop_products_tags`, `shop_special_deliveries`, `shop_tags`, `support_messages`, `support_tickets`, `search_entries`.

## 3. Anonymization rules

`config/anonymized_dump.yml` names every column. `AnonymizedDump::Classification.load` compares it to `db/schema.rb`. A new column fails `test/lib/anonymized_dump/classification_test.rb` until it is `keep`, a rewrite rule, or `drop`. The same test eager-loads models and requires every `encrypts` attribute to use an `encrypt_*` rule. `set_false` is the string rule for booleans. Do not write a bare YAML `false`. That becomes a boolean and the loader rejects it.

Seeds are SHA256(`seed_salt`, table, id, column). The same row gets the same stand-in on the next run. Names and streets come from Faker, locale from `members.language`, `admins.language`, `depots.language`, or the organization's first language (`fr`, `de`, `it`, `nl`, `en`). Zip and city are a single curated pair for CH, DE, FR, or NL so they match. Phones are E.164 for that country (`+41 79…`, `+49 151…`, `+31 6…`, `+33 6…`). Emails are `<slug>.<id>@mailinator.com`, one per original address, so the count stays. IBANs are ISO 13616 checksums for CH, DE, FR, or NL (`AnonymizedDump::IBAN`), checked with `IBANTools`. There is no birthday column.

Members already marked `anonymized_at` keep `DELETED` and blank fields. A leftover value that is not blank is still rewritten. SEPA IBANs on those members are rewritten. `Member::Anonymization` leaves mandates in place.

### Dropped tables

Rows are deleted. The tables stay so the app still boots.

| Tables | Why |
| --- | --- |
| `invoices`, `invoice_items` | Invoice documents, SEPA debtor names, pain payloads, amounts tied to a document. PDFs are Active Storage and are dropped with the blobs. |
| `active_storage_*` | File metadata and production object keys. |
| `mail_deliveries`, `mail_delivery_emails` | Rendered mail, subjects, Postmark ids. |
| `sessions` | Email, IP, user agent. `session_id` on kept tables is nulled first. `demo_page_visits` is deleted first because its `session_id` is NOT NULL. |
| `support_messages`, `support_tickets` | Free text, emails, tokens. Their Action Text rows (`Support::Message`, `Support::Ticket`) are deleted too. |
| `audits` | `audited_changes` is a copy of personal columns. |
| `email_suppressions` | Raw recipient addresses. |
| `demo_page_visits` | Admin browsing tied to sessions. |

`search_entries` is cleared and, when `reindex: true`, rebuilt from the anonymized rows. The published file should be built with reindex on, so agents get a search index of fake names.

### Rewritten columns

| Data | Rule |
| --- | --- |
| Member, admin, depot contact, and home-delivery names | `person_name` |
| `members.emails`, `members.billing_email`, `admins.email`, `depots.emails`, `basket_complements.emails`, `newsletters.from` | disposable address. Verifier rejects any other domain in these columns. |
| Phones, including carpooling | `phone` |
| Member and home-delivery street, zip, city | `street` / paired `zip` and `city`. Billing address is rewritten only when name, street, zip, and city are all present, so `different_billing_info` stays all-or-nothing. |
| Notes and free text (`members.note`, `food_note`, `profession`, `come_from`, `shares_info`, `delivery_note`, absence and participation notes, renewal notes, depot notes, admin comments, `admins.demo_message`) | `clear` |
| `members.contact_sharing` | `set_false` |
| Organization and mandate IBANs | `iban`. Mandate country stays the prefix of the original IBAN. `sepa_mandates.ip`, `user_agent`, and `umr` are cleared or replaced with `ANON` + 31 hex chars (the UMR format allows that). |
| `member_cards.number` | 16-digit stand-in. Cardholder name is a person name. |
| `payments.fingerprint`, `payments.invoice_id` | `clear`. Amount, date, currency, and member stay so cashflow shape remains after invoices are gone. |
| `organizations.api_token` | Re-encrypted placeholder `anon-api-token` under the current key. |
| `postmark_server_token`, `cap_secret_key`, `icalendar_auth_token`, `local_currency_secret` | SQL NULL. |
| `bank_connections.credentials` | Re-encrypted `{}`. The column is NOT NULL and the check constraint requires a JSON object. Rails stores the encrypted message as JSON, so the check still passes. |
| `bank_connections.settings`, `status_details` | `{}`. Host, partner, and user ids are not personal names but they are banking identifiers. |
| `local_currency_wallet`, `local_currency_identifier`, `postmark_server_id`, finalization `delivery_claim_token` | `clear` |
| `newsletters.liquid_data_preview_yamls` | `{}`. Previews are sample member data. |

`AnonymizedDump::Scrub` then walks remaining string, text, and JSON columns and replaces valid IBANs with the organization's new IBAN (or `[iban]` when the organization has none), strips `"signed_id"` keys, and removes `/rails/active_storage/…` URLs and `sgid` attributes.

### Left as-is, on purpose

Organization name, URL, public email, `email_default_from`, phones, creditor postal address, and VAT stay. The file is that organization's database. The tenant name is the file name. Rewriting the organization into a fictional CSA would throw away the operational shape the dump is for.

Depot street, zip, city, and map coordinates stay. They are pickup points. Depot contact name, email, phone, and note do not.

Membership, basket, and shop amounts stay. Payment amounts stay, without the bank fingerprint or the invoice link.

Mail templates, newsletter bodies, and Action Text that belongs to the organization, a depot, or a product stay. The verifier allows real email domains only on the columns listed under `email_policy.allow` (organization contact and org-authored mail). Every other string, text, or JSON column fails verification if it still contains an email. A new free-text column is `forbid` until someone classifies it.

Encrypted columns are not decrypted. `type.serialize` writes new ciphertext with whatever key this process booted with. Agents must boot with that same key. Production ciphertext is replaced, not converted.

## 4. Pipeline

Order, per tenant, on the scratch machine:

1. `litestream restore -o` into a scratch file. Stub: `AnonymizedDump::LitestreamRestore`.
2. Point the tenant shard at that file and run `AnonymizedDump::Anonymizer` (`reindex: true`).
3. `AnonymizedDump::Verifier`. Stop on any violation. Do not upload.
4. `VACUUM` outside the anonymizer transaction. SQLite refuses `VACUUM` inside a transaction.
5. Gzip. `AnonymizedDump::Publisher.compress` does this.
6. Upload. Stub: `Publisher.upload!`.
7. Heartbeat. `Pipeline.heartbeat` calls `Appsignal::CheckIn.cron("anonymized-dumps")` only when `ANONYMIZED_DUMP_HEARTBEAT=1` and the constant exists. A failed tenant must not check in.

Object keys:

- `tenants/<tenant>/YYYY-MM-DD.sqlite3.gz`
- `tenants/<tenant>/latest.sqlite3.gz`

`retention_days` is 30. Enforce it with a B2 lifecycle rule on the dated prefix. Overwrite `latest` each run. Do not delete `latest` with the lifecycle.

Secrets:

| Secret | Where | Scope |
| --- | --- | --- |
| Replica read key | Job host only | `csa-admin-litestream` Get/List. No delete, no write. |
| Anonymized write key | Job host only | Put on the new bucket. No replica access. |
| Anonymized read key | Cloud agent env | Get/List on the new bucket only. |
| Development master key | Job and agents | Encrypts the placeholder token and empty bank credentials. Not the production master key. |

Proposed env for agents and for `development:restore_anonymized`:

- `ANONYMIZED_DUMPS_BUCKET`
- `ANONYMIZED_DUMPS_ENDPOINT` (B2 S3 endpoint)
- `ANONYMIZED_DUMPS_REGION` (default `auto`)
- `ANONYMIZED_DUMPS_ACCESS_KEY_ID`
- `ANONYMIZED_DUMPS_SECRET_ACCESS_KEY`

`ANONYMIZED_DUMPS_LOCAL_DIR` skips the network and copies `<tenant>.sqlite3` or `<tenant>.sqlite3.gz`. Tests use that.

Suggested bucket name: `csa-admin-anonymized`. Not created here. Keep it out of `config/storage.yml`. That file is the member-file bucket `csa-admin-storage`.

Monitoring: one AppSignal cron check-in after every tenant succeeds. Log the tenant name, restore duration, byte size, and verifier result. Do not log row contents. The verifier messages include the offending value so a failed night is diagnosable on the job host. Those logs are still personal data if verification finds a leak. Keep them on the job host.

### Agent restore

```sh
bin/rails development:restore_anonymized[ragedevert,lamule]
```

or `TENANT=ragedevert,lamule`. Development only. Files land at `storage/development_<tenant>.sqlite3`, which is what `config/database.yml` already opens. WAL sidecars are removed so SQLite does not replay an old journal over the new file. Demo names are refused. Restart the app after a restore if it is running.

The downloaded file is already anonymized and, once the nightly job reindexes, already has `search_entries`. Agents do not need the replica key.

## 5. What is implemented

| Piece | Where |
| --- | --- |
| Classification | `config/anonymized_dump.yml` |
| Schema inventory and fail-closed load | `lib/anonymized_dump/schema_columns.rb`, `classification.rb` |
| Anonymizer | `lib/anonymized_dump/anonymizer.rb` |
| IBAN, Faker identity, text scrub | `iban.rb`, `identity.rb`, `scrub.rb` |
| Verifier | `verifier.rb` |
| Local anonymize / verify | `bin/rails anonymized_dump:anonymize` with `TENANT=` |
| Replica restore stub | `anonymized_dump:restore_replica` |
| Upload stub | `anonymized_dump:publish` |
| Agent download | `development:restore_anonymized` |
| Tests | `test/lib/anonymized_dump/` |

`anonymized_dump:anonymize` is destructive and development-only. It requires `TENANT` so it cannot walk every local database by accident. It vacuums and reindexes. `Pipeline.run!` is the nightly outline and currently raises on the restore stub before it touches the database.

## 6. Open questions for Thibaud

1. Where should the job run: a small VM, or a private GitHub Action? Both stay off the app host. An Action is less infrastructure. A VM is easier to give a disk and a Litestream binary.
2. Bucket name (`csa-admin-anonymized`?) and retention. 30 dated objects plus `latest` is the scaffold default.
3. Which tenants. All 39 `production` ones, or an explicit allowlist? Include `onboarding` (`pluk`, `zalpenblick`)? `microfermes` is `custom` but not a demo.
4. Legal. A dump with fake names can still be personal data under the FADP and GDPR when a small CSA can be re-identified from depot, basket size, and amounts. This scaffold is not a legal anonymization opinion. Needs a decision on purpose limitation, who may download, how long objects live, and whether the DPA with members and with Cursor covers handing the files to cloud agents.
5. Drop versus keep. Invoices and their PDFs are dropped. Payment, membership, and shop amounts are kept, with bank fingerprints removed. Depot addresses and the organization's own email, phone, and creditor address are kept. Banking `settings` are wiped. Say if payments should be dropped too, or if depot coordinates should be fuzzed.
6. Org-authored text (`email_policy.allow`) may still contain a farmer's name or the public inbox. The verifier does not treat that as a failure. Say if those columns should be cleared instead.
7. Whether `masker:run` / `development:restore:masked` should eventually call this anonymizer. Left unchanged so local workflows do not switch underneath you.
