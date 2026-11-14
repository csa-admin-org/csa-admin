---
name: browser
description: >
  CSA Admin UI QA in the browser: tenant launcher, admin/members origins,
  auto sign-in, and become-member. Use when opening the app, clicking through
  admin or members portals, or verifying UI. Not for production scraping or
  Query API (query skill).
---

# Browser

This skill owns CSA Admin origins and auth shortcuts. Drive the UI with the
environment’s built-in browser tools (Cursor Browser / computer use).

## Prefer the launcher

Open the tenant index first when picking a host:

| Context | URL |
| --- | --- |
| Cloud Agent / self-hosted / Mac `bin/dev` | `http://127.0.0.1:3000` or `http://localhost:3000` (development only, no basic auth) |
| Production ops | `https://mc.csa-admin.org` (HTTP basic) |
| This Mac with puma-dev | `https://mc.csa-admin.test` (or `mc` + app domain on `.test`) |

The page is config-only (`config/tenant.yml` via `Tenant.launcher_tenants`) —
no tenant DB. Filter with ⌘/Ctrl+K. One portal is selected and focused
at a time: ArrowUp/ArrowDown move by tenant (Admin); ArrowLeft/Right and
Tab / Shift+Tab step Admin → Members → next tenant. Enter from the
search field opens Admin. Links already use the right origin for the
current env (`Tenant.local_url`).

Resolve hosts from that list or from `config/tenant.yml`. Do **not** invent
hosts from the tenant slug. `acme` is test-only.

## Origins

**Default (Cloud Agent, self-hosted VM, and Mac with `bin/dev`):**

- Admin: `http://admin.<sld>.localhost:3000`
- Members: members host from tenant config, same `.localhost:3000` rewrite
  (often `http://membres.<sld>.localhost:3000`)
- Expect `bin/dev` (and forwarded port `3000` on VMs)

**This Mac only (optional):** puma-dev with `https://admin.<sld>.test` /
`https://membres.<sld>.test` (or the locale members host). Use when that is
already how the machine is running — do not require it on cloud agents.

Admin and members portals are separate auth contexts. Cookies are
host-scoped — keep one host for a given session.

## Auth

### Admin auto sign-in (development)

When `auto_sign_in_admin_email` is set (`.env` /
`AUTO_SIGN_IN_ADMIN_EMAIL`, or the environment secret mapped into creds),
visiting an `admin` subdomain in development signs in that admin with no
login form. Prefer this over typing passwords.

### Members: become from admin

Do not password-login as a member for QA. In admin, open the member, then
use the become control (`become_member` / `become-member#open`, label like
“open admin session”) to open a members-portal session in a new tab.
