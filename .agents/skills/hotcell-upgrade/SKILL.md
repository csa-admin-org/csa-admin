---
name: hotcell-upgrade
description: >
  Operator runbook for upgrading Hot Cell gems, cell image config, and CI
  conformance pin in CSA Admin. Use only when explicitly invoked. Covers
  client/server lockfiles, manual cell file updates, conformance SHA, and
  automated or manual release of the activestorage-hotcell accessory. Not for Query
  API, locale copy, or a normal app deploy.
when-to-use: Use when the user invokes hotcell-upgrade or asks to upgrade Hot Cell.
argument-hint: "[target hotcell version]"
disable-model-invocation: true
---

# Hot Cell upgrade

Active Storage image processing runs in the `activestorage-hotcell` Kamal accessory (`config/deploy.yml`), tagged with a 12-char content hash from `bin/hotcell-image-tag`. The `Deploy` workflow (`.github/workflows/deploy.yml`) runs `bin/hotcell-release` before `bundle exec kamal deploy`, automatically building, pushing, and booting/rebooting the cell whenever the `hotcell/` build inputs change. Run `bin/hotcell-release` by hand to release outside CI (pass `--force` to rebuild and reboot even when the tag is unchanged).

## Steps

1. Bump `activestorage-hotcell-client` in `Gemfile` and the `activestorage-hotcell-server` / `hotcell-server` pins in `hotcell/Gemfile` together to the same version, then refresh both lockfiles (`bundle update activestorage-hotcell-client` at the repo root and `cd hotcell && bundle update`, keeping Linux platforms in `hotcell/Gemfile.lock`).
2. Read the upstream `basecamp/hotcell` `CHANGELOG.md` `Upgrading` sections for every release between the old and new version.
3. Apply manual changes to `hotcell/Dockerfile` and `hotcell/config.rb` — the installer never rewrites existing files (check limits, packages, and runtime env vars such as `OMP_NUM_THREADS` / `OMP_THREAD_LIMIT`, where `OMP_NUM_THREADS` must match `activestorage-hotcell` `cpus` in `config/deploy.yml`).
4. Bump the pinned `basecamp/hotcell` `ref:` in the `hotcell` job of `.github/workflows/ci.yml` to the full commit SHA of the matching tag with a `# vX.Y.Z` comment.
5. Run `bin/ci` until green.
6. Ensure `kernel.yama.ptrace_scope >= 1` on `isle.thibaud.gg` (manual one-time host check; Hot Cell refuses to boot at `0`).
7. Merge to `master` so the `Deploy` workflow builds, pushes, and boots/reboots `activestorage-hotcell` before deploying the app (or run `bin/hotcell-release` manually, with `--force` to force a rebuild), then check `bundle exec kamal hotcell-logs`.

If `.workbench/tasks/hotcell.md` exists in the checkout, check it for local operator notes.
