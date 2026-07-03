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
