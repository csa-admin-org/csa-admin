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
    "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(
      scope: "DE",
      container: "XML",
      version: nil)
  }
}
```

Useful EBICS checks:

```sh
TENANT=tenant bin/rails ebics:readiness
TENANT=tenant bin/rails ebics:capabilities
TENANT=tenant bin/rails ebics:monitor
TENANT=tenant FROM=2026-07-01 TO=2026-07-03 bin/rails ebics:btf_download
TENANT=tenant FROM=2026-07-01 TO=2026-07-03 ACK=true bin/rails ebics:btf_download
```

Run `ACK=true` only when you accept that returned payment data may be marked as
consumed by the bank.

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
active key blob encrypted in `credentials["previous_key_rotation"]["keys"]`.

After the flow is proven for a bank, the guarded all-in-one command is available:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:perform
```

For a proven bank/provider, use the batch commands to rotate selected tenants
sequentially. Always inspect the plan first. `TENANTS` is a comma/space-separated
list. `PROVIDER` matches the active bank connection provider (`ebics`) or bank
name/host id (`RAIFCHEC`, `PFEBICS`, etc.). Already-4096-bit or already-rotated
connections are reported as `noop` and the batch continues to the next tenant.
Unsupported or blocked tenants are skipped; a failed attempted rotation stops the
batch.

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

Run the live sequence one tenant at a time for the reviewed set:

```sh
TENANTS=tenant-a,tenant-b CONFIRM=true bin/rails ebics:key_rotation:batch:perform
PROVIDER=RAIFCHEC CONFIRM=true bin/rails ebics:key_rotation:batch:perform
```

Add `VERIFY_PAYMENTS=true` to run `Billing::PaymentsProcessor.retrieve_and_process!`
after each successful promotion. Use `ALL=true` only when intentionally applying
the command to every eligible active EBICS connection.

Rollback is also a live `HCS` key change. It rotates the bank back to the
encrypted previous key set, verifies those keys with `HTD`, then promotes them
locally:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:rollback
```

If a live submit has an uncertain outcome, do not retry `submit`. Run
`verify` with the pending keys; if it succeeds, run `promote`. If it fails,
inspect `status_details["key_rotation"]`, keep both active and pending key sets,
and coordinate with the bank before doing anything else.

If a live rollback has an uncertain outcome, do not retry `rollback` because that
would submit another `HCS`. First try the recovery task, which verifies the
previous key set with `HTD` and promotes it locally without another key-change
submission:

```sh
TENANT=tenant CONFIRM=true bin/rails ebics:key_rotation:recover_rollback
```

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
