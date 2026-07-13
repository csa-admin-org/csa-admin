# Bank connections console runbook

CSA Admin stores payment-import and EBICS upload configuration in the tenant-local
`bank_connections` table. There is no `organization_id`: switch to the tenant
first, then create or update the row in that tenant database.

```ruby
Tenant.switch("acme") do
  Current.org.active_bank_connection
  BankConnection.active.first
end
```

Keep these rules in mind:

- Only one `BankConnection` can be active per tenant.
- Use `active: true` and `state: "ready"` only after the credentials and bank
  operation settings have been tested.
- Store secrets only in `credentials`; that column is encrypted. Do not paste
  real credentials, key material, CAMT/PAIN payloads, or signed EBICS XML into
  docs, chats, task files, or logs.
- Provider-specific runtime metadata belongs in `settings`, `capabilities`, and
  `status_details`, never in `organizations`.
- New EBICS connections must be EBICS 3.0 / H005 / BTF. CSA Admin no longer
  supports creating EBICS 2.x/H003/H004 order-type connections.
- EBICS endpoint URLs must use HTTPS and must not contain URL userinfo such as
  `user:password@host`.

## EBICS 3.0 / H005 / BTF

Use EBICS only when the bank can activate EBICS 3.0/H005 with BTF downloads
and, when needed, BTF uploads. Required credential keys are:

- `url`
- `host_id`
- `participant_id`
- `client_id`
- `secret`
- `keys` — encrypted CSA Admin EBICS key material, including participant and
  bank keys

Swiss payment-import example using camt.054:

```ruby
Tenant.switch("tenant") do
  BankConnection.create!(
    provider: "ebics",
    name: "RAIFCHEC",
    active: true,
    state: "ready",
    credentials: {
      "url" => "https://ebics.bank.example/ebics",
      "host_id" => "HOSTID",
      "participant_id" => "PARTNERID",
      "client_id" => "USERID",
      "secret" => "...",
      "keys" => "... encrypted EBICS key JSON ..."
    },
    settings: {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(
            service_name: "REP",
            scope: "CH",
            version: "04")
        }
      }
    })
end
```

German/MULTIVIA-style payment-import example using camt.053 exactly as
advertised without a message version. Keep the same top-level
`"protocol" => "H005"` setting:

```ruby
"downloads" => {
  "payments" => {
    "mode" => "btf",
    "btf" => Billing::EBICS::Btf::Presets.camt053(
      service_name: "EOP",
      scope: "DE")
  }
}
```

SEPA direct-debit upload example. Keep the same top-level
`"protocol" => "H005"` setting:

```ruby
"uploads" => {
  "sepa_direct_debit" => {
    "mode" => "btf",
    "schema" => "pain.008.001.08",
    "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: nil)
  }
}
```

CSA Admin uploads a bare `pain.008` document and therefore requires the
non-container `BTU / SDD / COR / pain.008` service. Do not add `scope: "DE"`
or `container: "XML"`: that tuple declares the German DK XML-container
variant, whose payload format CSA Admin does not generate. Confirm that the
bank advertises the non-container service before activating direct-debit
uploads. CSA Admin keeps EBICS direct-debit uploads unavailable until the stored
HTD capabilities contain that service.

A successful H005 `BTU` direct-debit upload means the EBICS transport accepted
the file and returned a transaction/order identifier. It is not final proof that
the bank or payment scheme executed every debit. Use bank-side status reporting
such as `pain.002` where available, or the bank portal/support process, for final
acceptance and rejection details.

CSA Admin claims an invoice before the live upload and persists a stable PAIN
message ID, generation timestamp, and payload digest. `submitting` and `uncertain`
outcomes are never retried automatically. If a response is lost, reconcile the
message ID and any transaction/order ID with the bank before changing state. Only
a confirmed pre-acceptance failure may be marked `failed` for an explicit retry:

```sh
TENANT=tenant \
  INVOICE_ID=123 \
  CONFIRM=true \
  BANK_CONFIRMED_NOT_ACCEPTED=true \
  bin/rails ebics:sepa_direct_debit:confirm_not_accepted
```

The guarded task accepts only an `uncertain` submission with no bank order ID and a
complete persisted PAIN identity. It does not call the bank. The next explicit or
scheduled retry reuses the original PAIN identity and is refused if the reconstructed
payload no longer matches its persisted digest.

CAMT imports now use stable bank references as payment fingerprints. During the
cutover, a single unambiguous legacy payment without a fingerprint is upgraded in
place. Ambiguous equal-payment groups are skipped and emit
`payment_processing_legacy_camt_fingerprint_ambiguous`; reconcile those records
before reprocessing rather than guessing or inserting another payment.

Useful billing and EBICS checks:

```sh
bin/rails billing:health
PROVIDER=ebics bin/rails billing:health
TENANTS=tenant-a,tenant-b bin/rails billing:health
TENANT=tenant bin/rails ebics:readiness
TENANT=tenant bin/rails ebics:capabilities
TENANT=tenant bin/rails ebics:monitor
TENANT=tenant FROM=2026-07-01 TO=2026-07-03 bin/rails ebics:btf_download
TENANT=tenant FROM=2026-07-01 TO=2026-07-03 ACK=true bin/rails ebics:btf_download
```

`billing:health` is read-only and prints the active bank connection for each
selected tenant, including provider/name, health status, latest import date,
runtime version, EBICS subscriber-key strength (`2048`/`4096`), and any actionable
key-rotation/error note. Successful rotations are implied by `4096`; failed HCS
attempts stay visible as `HCS failed; kept 2048` until the bank-specific issue is
resolved.

`ebics:btf_download` uses the active connection's configured payment-download
BTF tuple. It intentionally does not fall back to the country preset, so it is a
safe way to prove the exact production configuration before a live import.

Run `ACK=true` only when you accept that returned payment data may be marked as
consumed by the bank.

### EBICS onboarding backend/operator flow

New EBICS connections are initialized through the CSA Admin H005 setup backend. The
flow creates an inactive tenant-local `bank_connections` row first, then submits
`INI`/`HIA`, writes the printable initialization letter, waits for the bank to
activate the subscriber, and finally runs `HPB` to fetch bank public keys.

Create encrypted participant credentials and store only sanitized setup metadata:

```sh
TENANT=tenant \
  URL=https://ebics.bank.example/ebics \
  HOST_ID=HOSTID \
  CLIENT_ID=CLIENTID \
  PARTICIPANT_ID=PARTICIPANTID \
  NAME="Bank name" \
  CONFIRM=true \
  bin/rails ebics:onboarding:initialize
```

The default participant key size is 4096-bit RSA. Use `KEY_BITS=2048` only when a
bank explicitly requires it for a new subscriber. The generated `A006`, `X002`, and
`E002` private keys are stored in versioned AES-256-GCM key blobs inside the
encrypted `credentials["keys"]` column. Older AES-256-CBC blobs remain readable for
existing rows; rake output and `status_details["onboarding"]` contain only public
metadata, sizes, hashes, and state transitions.

Inspect status before submitting live setup orders:

```sh
TENANT=tenant bin/rails ebics:onboarding:status
```

Submit setup orders only after reviewing the status:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:onboarding:submit_ini
TENANT=tenant CONFIRM=true bin/rails ebics:onboarding:submit_hia
```

`INI` and `HIA` are live bank calls. CSA Admin records a `*_submit_started_at`
timestamp before posting to the bank so an interrupted request is visible and not
silently retried as if nothing happened. Any setup with an INI/HIA start marker is
preserved with its encrypted keys, even when the response is lost. Do not delete it,
generate replacement keys, or resubmit the same order until the bank confirms the
subscriber state. After `HIA`, the connection stays inactive and moves to
`waiting_for_bank` until the signed letter has been sent and the bank confirms
activation.

Generate the signed-bank letter PDF after `HIA` has moved the connection to
`waiting_for_bank`:

```sh
TENANT=tenant LOCALE=fr OUTPUT=tmp/tenant-ebics-letter.pdf bin/rails ebics:onboarding:letter
```

If multiple draft/onboarding EBICS connections exist, pass `BANK_CONNECTION_ID=...`.
The letter uses the EBICS 3.0 certificate format: one page each for the `A006`
signature certificate, `X002` authentication certificate, and `E002` encryption
certificate. It prints public certificates and SHA-256 fingerprints only, never
private keys, encrypted credentials, signed request XML, or EBICS signatures.

Finalize only after bank activation:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:onboarding:finalize
```

Finalization runs `HPB` without requiring pre-existing bank public keys, stores the
bank `HOSTID.X002` and `HOSTID.E002` public keys into encrypted credentials, then
verifies the finalized credentials with `HTD`. If verification succeeds, CSA Admin
activates the tenant-local row, marks it `ready`, records the bank keys, and runs
a follow-up capability check. The connection may still show a payment-automation
warning until the active download/upload settings and bank capabilities are fully
verified.

The scheduled finalizer checks each waiting setup at most once per day. The explicit
operator `finalize` command may retry sooner after a reviewed transient/not-ready
result, but competing finalizations are rejected through an operation claim.
Finalization also creates a tenant-local notification outbox in the same transaction.
Delivery is durable and duplicate queued jobs skip completed rows; as with normal
email delivery, a process crash after the mail provider accepts a message but before
the local delivered marker is saved remains an at-least-once delivery window.

HPB is the bootstrap trust boundary: the first HPB response cannot be EBICS
signature-verified because the bank signing keys are what it returns. Trust the
bank keys only when the HTTPS endpoint, Host ID, client/participant identifiers,
HEV Host ID check, and bank-side subscriber activation all match the bank
contract. If the bank provides public-key fingerprints, compare them with the
sanitized HPB/key-summary output before treating the connection as fully trusted.

### EBICS subscriber key rotation

EBICS subscriber key rotation is an operator-only runbook. Do not expose it as an
admin UI action and do not run it automatically across tenants. CSA Admin keeps
EBICS 3.0 / H005 / BTF as the only supported runtime protocol; the fixed
subscriber key target is 4096-bit RSA. Existing 4096-bit connections are already
at target, and 2048-bit remains supported when a bank explicitly cannot accept
4096-bit subscriber keys.

Start with the read-only inventory:

```sh
bin/rails ebics:key_rotation:readiness
TENANT=tenant bin/rails ebics:key_rotation:readiness
```

The report is sanitized. It includes tenant/host grouping, protocol status,
participant and bank key sizes, public-key digests, blockers, pending rotation
state, and one of these states:

- `already_at_target`
- `candidate`
- `bank_limited_2048`
- `blocked`
- `unknown`
- `pending_rotation`
- `rotation_failed`
- `rotated`

CSA Admin reports `candidate` only when `HCS` is advertised in stored H005
capabilities or explicitly confirmed in settings. `HCS` replaces all subscriber
keys (`A006`, `X002`, and `E002`) and is the only key-change order CSA Admin uses
for 4096-bit rotation. Do not treat a bank as live-rotation capable just because
the current keys are 2048-bit.

Known 2048-bit exceptions should remain explicit in `billing:health` and
`status_details["key_rotation"]`: keep them on 2048-bit when `HCS` is absent or a
bank rejected HCS while active imports remain healthy.

Prepare pending 4096-bit participant keys only for a single tenant and only
after reviewing the readiness report:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:prepare
```

This writes encrypted pending A/X/E participant keys to
`credentials["pending_key_rotation"]["keys"]`, keeps the active
`credentials["keys"]` untouched, and records only sanitized digests/sizes in
`status_details["key_rotation"]`. Running it for an already-4096-bit connection
is a no-op.

Validate the local prerequisites and sanitized metadata before doing any manual
bank coordination:

```sh
TENANT=tenant bin/rails ebics:key_rotation:validate
# Same validation alias:
TENANT=tenant bin/rails ebics:key_rotation:build
```

The validation task builds the local `HCS` request and order-data XML in memory,
but prints only root names, byte sizes, and SHA-256 digests. It does not print
private keys, encrypted credential blobs, raw EBICS XML, signatures, or request
payloads.

Run live rotation one step at a time for the first tenant:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:submit
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:verify
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:promote
```

`submit` performs the live two-phase `HCS` upload using the current active keys
and the pending public keys. `verify` performs an `HTD` admin-order check using
the pending keys. `promote` is local-only and overwrites active
`credentials["keys"]` only after verification succeeded; it keeps the previous
active key blob encrypted in `credentials["previous_key_rotation"]["keys"]` as a
short manual-recovery aid.

After the flow is proven for a bank, the guarded all-in-one command is available:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:perform
```

Use batch commands for read-only planning and local pending-key preparation only.
Always inspect the plan first. `TENANTS` is a comma/space-separated list.
`PROVIDER` matches the active bank connection provider (`ebics`) or bank name/host
id (`RAIFCHEC`, `PFEBICS`, etc.). Already-4096-bit or already-rotated connections
are reported as `noop`; unsupported or blocked tenants are skipped.

```sh
bin/rails ebics:key_rotation:batch:plan
PROVIDER=RAIFCHEC bin/rails ebics:key_rotation:batch:plan
TENANTS=tenant-a,tenant-b bin/rails ebics:key_rotation:batch:plan
```

Prepare pending keys for a reviewed set without live bank calls:

```sh
TENANTS=tenant-a,tenant-b CONFIRM=true bin/rails ebics:key_rotation:batch:prepare
PROVIDER=RAIFCHEC CONFIRM=true bin/rails ebics:key_rotation:batch:prepare
```

Run the live all-in-one batch sequence for exactly one reviewed tenant:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:batch:perform
TENANT=tenant CONFIRM=true VERIFY_PAYMENTS=true bin/rails ebics:key_rotation:batch:perform
```

`batch:perform` rejects `TENANTS`, `PROVIDER`, and `ALL=true` to avoid
provider-wide live-bank blast radius. It prepares missing pending keys for a
`candidate` tenant before validating/submitting. Add `VERIFY_PAYMENTS=true` to run
`Billing::PaymentsProcessor.retrieve_and_process!` after a successful promotion.

If a live submit has an uncertain outcome, do not retry `submit`. Run `verify`
with the pending keys; if it succeeds, run `promote`. If it fails, inspect
`status_details["key_rotation"]`, keep the active key set, and coordinate with the
bank before doing anything else. When the bank confirms that the new keys were not
accepted and the old active keys still work, discard the pending local key set
without changing active keys:

```sh
TENANT=tenant CONFIRM=true REASON=bank_rejected_hcs bin/rails ebics:key_rotation:discard_pending
```

The discard task is local-only and safe to rerun. It removes
`credentials["pending_key_rotation"]` when present, keeps active
`credentials["keys"]`, and keeps a sanitized `rotation_failed` status so batch
rotation skips that tenant until the bank-specific issue is resolved.

After a verified rotation has been live long enough to confirm payment imports,
purge the retained previous key blob locally:

```sh
TENANT=tenant CONFIRM=true REASON=verified_after_rotation bin/rails ebics:key_rotation:purge_previous
```

The purge task removes only `credentials["previous_key_rotation"]`, keeps active
`credentials["keys"]`, and records the sanitized purge timestamp/reason. It makes
recovery depend on backups/bank coordination instead of retaining old private keys
indefinitely.

## BAS

BAS connections use the bank keyfile flow instead of EBICS.

```ruby
Tenant.switch("tenant") do
  BankConnection.create!(
    provider: "bas",
    name: "BAS 123.456.789-00",
    active: true,
    state: "ready",
    credentials: {
      "account_number" => "123.456.789-00",
      "contract_number" => "IB1234567",
      "contract_password" => "...",
      "private_key" => "... keyfile private key ..."
    })
end
```

## bunq

Prefer the setup task because bunq requires API installation/device/session
registration:

```sh
TENANT_NAME=tenant BUNQ_API_KEY=... bin/rails bunq:setup
```

The task stores progress in an inactive `initializing` `bank_connections` row
and marks it active/ready only after the monetary account is selected. A ready
bunq connection contains credentials such as:

- `api_key`
- `private_key`
- `installation_token`
- `server_public_key`
- `device_id`
- `user_id`
- `monetary_account_id`

## Mock

Use mock connections only in local/test tenants.

```ruby
Tenant.switch("tenant") do
  BankConnection.create!(
    provider: "mock",
    name: "Mock bank",
    active: true,
    state: "ready",
    credentials: { "password" => "secret" })
end
```

## Migration and recovery safety

`bank_connections` contains the only current payment-provider credentials. The
legacy `organizations.bank_connection_type` and `organizations.bank_credentials`
columns were removed after the production backfill. Those migrations are explicitly
irreversible: rolling them back cannot reconstruct credentials and dropping
`bank_connections` would destroy the active encrypted key material.

Before deploying tenant-wide bank-connection migrations:

1. take and verify a restorable backup of every tenant database;
2. run the migration preflight and resolve any active/non-ready or duplicate
   onboarding rows without guessing lifecycle state;
3. migrate all tenants;
4. verify each active connection resolves as `ready` and that EBICS payment tuples
   still match the bank-advertised H005/BTF configuration.

Recovery from a failed destructive migration is restore-only. No backfill or
rollback script can reconstruct the removed legacy credentials.

## Verify payment imports

Dry-run first:

```sh
bin/rails billing:payments:process TENANT=tenant
bin/rails billing:payments:process PROVIDER=ebics
bin/rails billing:payments:process ALL=true
```

Run the live import only after reviewing the dry-run result:

```sh
bin/rails billing:payments:process TENANT=tenant CONFIRM=true
```

The JSON output should report `source: "bank_connections"`, the expected
provider, and a healthy status after a successful import or no-data response.
