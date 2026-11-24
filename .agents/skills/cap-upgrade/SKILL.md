---
name: cap-upgrade
description: >
  Operator runbook for the next self-hosted capd upgrade on
  cap.csa-admin.org. Use only when explicitly invoked. Covers the Kamal
  accessory, secret rotation, protocol pin, and the traps from the 4.0.14
  cutover. Not for Query API, locale copy, or a normal app deploy.
when-to-use: Use when the user invokes cap-upgrade or asks to upgrade the production Cap accessory.
argument-hint: "[target capd version]"
disable-model-invocation: true
---

# Cap upgrade

Self-hosted capd at `https://cap.csa-admin.org`. Accessory `cap` in `config/deploy.yml`, Valkey sibling `cap-valkey`, data on the host bind mount `/root/csa-admin-cap/cap-data`. Site keys and encrypted `cap_secret_key` live on `organizations`. Rakes: `lib/tasks/cap.rake`. HTTP: `Cap::Client`.

Do not print `ADMIN_KEY`, `cap_api_key`, or a site secret. `CAP_ADMIN_KEY` in `.env` is the dashboard login only. `CSA_ADMIN_API_TOKEN` is the Query API. Neither is the Cap API key.

Read the target release notes and `capd/src/server.js` for that tag before changing the pin. Confirm create, `/siteverify`, and rotate still match what the rakes send. Stop if they do not.

## Before the image switch

1. App code can ship first. Leave the accessory on the running tag until the backup exists.
2. Snapshot Valkey inside the running container. `kamal accessory exec` starts a new container and cannot reach it.

   ```bash
   ssh isle.thibaud.gg 'docker exec csa-admin-cap-valkey valkey-cli SAVE'
   ```

   The dump is a bind mount, not a Docker volume: `/root/csa-admin-cap-valkey/cap-valkey-data/dump.rdb`. Copy it off isle and check the sha256. The hourly `--save 60 1` is not this backup. Rollback is that file plus the previous image tag.
3. `kamal accessory reboot cap`. Not `kamal cap-boot`. That alias is `accessory boot`, which will not recreate a running container onto a new tag. Do not reboot `cap-valkey`. `cap-data` is already mounted.

## After boot

Confirm `GET /health` is 200 and read `docker logs csa-admin-cap`.

- Startup lists site keys whose stored hash is not `sha256:…`, and API keys in the same state. That is the rotate set. Do not rotate a key that is absent from that list. capd 4 did not reject every v3 secret.
- `ENABLE_ASSETS_SERVER`, `WIDGET_VERSION`, and `WASM_VERSION` are copied into Settings > Widget files only when that setting is missing. Once saved, env is ignored. Confirm widget and wasm by curling `/assets/widget.js` and `/assets/cap_wasm_bg.wasm`. The app pin in `config/importmap.rb` is a URL, not a version. Do not edit it for a version bump.
- `RATELIMIT_IP_HEADER` is not read. Visitor IP is `PUT /server/settings/headers` with `{ ipHeader: "CF-Connecting-IP" }`.

## API key

A v4 API key is `id_token` and must contain `_`. A key without `_` is 401, including the previous dashboard key. Only a dashboard session can mint the replacement.

Login is `POST /auth/login` with `{ admin_key }`. The session `Authorization` header is `Bearer` plus base64 of `{ token, hash }` from `session_token` and `hashed_token`. Create an unscoped write key (`siteKeys` omitted, `readonly` not set). The token is returned once. If a key was created and the token was not saved, delete that key and mint another. Do not keep two current keys.

Write it as `cap_api_key` in `config/credentials.yml.enc`. Kamal builds from a git clone of the main checkout and ignores an uncommitted file, a worktree commit, and `deploy --version` pointing at a local-only SHA. Commit on `master`, push, then `kamal deploy`. Deploying before the push lets the next CI deploy rebuild without the key and restore the 401.

Delete the old API key only after a rotate dry-run with the new key succeeds.

## Protocol, then secrets

Both from the job container, so they use `CAP_INTERNAL_API_URL`. Protocol first. It does not cut `/siteverify`.

```bash
kamal app exec -r job "bin/rails cap:pin_sha256"
kamal app exec -r job "bin/rails cap:pin_sha256 CONFIRM=1"
kamal app exec -r job "bin/rails cap:rotate_secrets"
kamal app exec -r job "bin/rails cap:rotate_secrets CONFIRM=1"
```

`CONFIRM` is exact `1`. `true` and `yes` do not write.

`cap:pin_sha256` walks Cap keys, not tenants, so the development key is included. `GET /server/keys` is a bare array and has no protocol. Protocol is `GET /server/keys/:siteKey` → `key.config.protocol`. A pin `PUT` body is only `{ protocol: "sha256-pow" }`. Skip a key that already stores that. Abort with no writes if any stored protocol is present and not `sha256-pow`. v4 create defaults to `hashwx` when `protocol` is omitted, so do not drop it from `cap:setup`.

`cap:rotate_secrets` skips custom tenants unless `TENANT=` is set, same as `cap:setup`. After the full walk, run `TENANT=demo-fr,demo-en,demo-de,microfermes` (and any other custom). A skipped outdated key prints as missing from the walk. Pin does not need that second run. The development secret lives in `.env` (`CAP_DEVELOPMENT_SECRET_KEY`), not on an org row. Rotate it by hand only if startup listed it.

A save failure after rotate prints that one secret and stops. Cap returns it once. A second rotate replaces it. A killed process between the POST and the save cannot print it. Recover that one from the dashboard.

Do not pass `FORCE=1` to `cap:setup` to upgrade a tenant that already has a key. That creates a second key and orphans the first.

## Verify

Restart `csa-admin-cap` and read the new startup log. No "older release" lines for site keys or API keys. The widget-env deprecation line is expected once Settings > Widget files is saved.

A headless browser redeem 403 with `automated_browser` is `blockAutomatedBrowsers`, not a bad secret. Confirm challenge is 200, then smoke a normal browser. A 403 body that mentions an older secret means that tenant was not rotated.

An AppSignal `RuntimeError: Missing CAP_API_KEY` from these rakes is a run that did not see the new credential. Close it after a dry-run on the deployed image succeeds.
