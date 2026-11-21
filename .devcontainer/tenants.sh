#!/usr/bin/env bash
# Run on the macOS host (APFS clones): point a worktree's devcontainer at some tenants and fill their data.
#
#   .devcontainer/tenants.sh demo-en,demo-fr             # APFS clone of the DB and storage/<tenant>, as-is
#   .devcontainer/tenants.sh <tenant> --restore          # development:restore (litestream + storage backup)
#   .devcontainer/tenants.sh demo-en --empty             # drop local DB and storage, then schema + seeds
#   .devcontainer/tenants.sh <tenant> --masked           # clone, then masker:run and search:reindex (non-demo tenants)
#   .devcontainer/tenants.sh <tenant> --restore --masked # same steps as development:restore:masked
#
# Rewrites the worktree's config/tenant.yml development section and marks the
# whole file skip-worktree, so a later pull will not update production hosts
# here until `git update-index --no-skip-worktree config/tenant.yml`.
# Each worktree gets its own SQLite files: two servers writing one file corrupts it.
set -euo pipefail

usage() {
  sed -n '4,8s/^# \{0,1\}//p' "$0" >&2
  exit 1
}

mode=clone
mask=0
tenants=
for arg in "$@"; do
  case $arg in
    --restore|--empty)
      if [[ $mode != clone ]]; then
        echo "Use only one of --restore and --empty." >&2
        exit 1
      fi
      mode=${arg#--}
      ;;
    --masked) mask=1 ;;
    -*) echo "Unknown option: $arg" >&2; usage ;;
    *) [[ -z $tenants ]] || usage; tenants=$arg ;;
  esac
done
if [[ ! $tenants =~ ^[a-z0-9-]+(,[a-z0-9-]+)*$ ]]; then
  usage
fi
if [[ $mode == restore && -z ${CSA_ADMIN_BACKUPS_PATH:-} ]]; then
  echo "--restore needs CSA_ADMIN_BACKUPS_PATH (the backups folder)." >&2
  exit 1
fi
if [[ $mode == empty && $mask == 1 ]]; then
  echo "--masked does not apply to --empty (those databases are seeded, not copied)." >&2
  exit 1
fi

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
main=$(git -C "$root" worktree list --porcelain | sed -n '1s/^worktree //p')
backup=${CSA_ADMIN_BACKUPS_PATH:-}
if [[ $root == "$main" ]]; then
  echo "Run this in a worktree, not the main checkout." >&2
  exit 1
fi

container=$(docker ps -q --filter "label=devcontainer.local_folder=$root")
if [[ -z $container ]]; then
  echo "No running devcontainer for $root (mise run wt:up, or npx @devcontainers/cli up --workspace-folder $root)." >&2
  exit 1
fi

in_container() {
  docker exec -u vscode -w /workspaces/app "$container" bash -lic "$1"
}

echo "== Stopping bin/dev and the cursor worker =="
docker exec "$container" sh -c 'pkill -f "[p]uma.*tcp://" || true; pkill -f "[c]ursor-agent.* worker " || true'

echo "== Writing config/tenant.yml for $tenants =="
in_container "ruby -ryaml -e '
  path = \"config/tenant.yml\"
  tenants = \"$tenants\".split(\",\")
  production = YAML.load_file(path, aliases: true).fetch(\"production\")
  unknown = tenants - production.keys
  abort \"Unknown tenant(s): #{unknown.join(\", \")}\" if unknown.any?
  development = { \"development\" => production.slice(*tenants) }.to_yaml.delete_prefix(\"---\n\")
  original = File.read(path)
  updated = original.sub(/^development:\n.*?(?=^\\S|\\z)/m, development + \"\n\")
  abort \"config/tenant.yml has no development section to replace\" if updated == original
  File.write(path, updated)
'"
# Zed's git status refresh can hold index.lock for a moment.
skip_ok=0
for _ in 1 2 3 4 5; do
  if git -C "$root" update-index --skip-worktree config/tenant.yml 2>/dev/null; then
    skip_ok=1
    break
  fi
  sleep 1
done
if [[ $skip_ok -ne 1 ]]; then
  echo "Could not mark config/tenant.yml skip-worktree." >&2
  exit 1
fi

IFS=, read -ra names <<<"$tenants"
case $mode in
  clone)
    echo "== Cloning from $main/storage (APFS copy-on-write) =="
    for t in "${names[@]}"; do
      db=$main/storage/development_$t.sqlite3
      [[ -f $db ]] || { echo "Missing $db" >&2; exit 1; }
    done
    for t in "${names[@]}"; do
      db=$main/storage/development_$t.sqlite3
      rm -rf "$root/storage/development_$t.sqlite3"* "$root/storage/$t"
      mkdir -p "$root/storage"
      # Back-to-back clones of the live DB and its WAL. Not a SQLite checkpoint.
      cp -c "$db" "$root/storage/"
      [[ -f $db-wal ]] && cp -c "$db-wal" "$root/storage/"
      assets=$main/storage/$t
      if [[ -d $assets ]]; then
        mkdir -p "$root/storage/$t"
        # Each blob is its own clone. cp -cR of the directory inode is not enough.
        cp -cR "$assets"/. "$root/storage/$t"/
        echo "$t: $(du -sh "$root/storage/development_$t.sqlite3" | cut -f1) DB, $(du -sh "$root/storage/$t" | cut -f1) storage"
      else
        echo "$t: $(du -sh "$root/storage/development_$t.sqlite3" | cut -f1) DB, no storage/"
      fi
    done
    ;;
  restore)
    echo "== Restoring from $backup =="
    # One-off container: the agent container never sees the backups. Backups are
    # read-only; litestream-restore/ is the scratch tree development:restore rebuilds.
    # BACKUP_PATH is what Rails.app.creds.require(:backup_path) reads first.
    image=$(docker inspect -f '{{.Config.Image}}' "$container")
    docker run --rm -u vscode -w /workspaces/app \
      -e MISE_TRUSTED_CONFIG_PATHS=/workspaces/app \
      -e "BACKUP_PATH=$backup" \
      -v "$root:/workspaces/app" \
      -v "$main/.git:$main/.git:ro" \
      -v "$backup:$backup:ro" \
      -v "$backup/litestream-restore:$backup/litestream-restore" \
      "$image" bash -lic "bin/rails development:restore"
    ;;
  empty)
    echo "== Removing local DB and storage for a fresh schema =="
    for t in "${names[@]}"; do
      rm -rf "$root/storage/development_$t.sqlite3"* "$root/storage/$t"
    done
    ;;
esac

echo "== Preparing databases =="
in_container "bin/rails db:prepare"

if [[ $mask == 1 ]]; then
  private=()
  for t in "${names[@]}"; do
    [[ $t =~ ^demo-[a-z]{2}$ ]] || private+=("$t")
  done
  if (( ${#private[@]} )); then
    echo "== Masking private data =="
    in_container "TENANT=$(IFS=,; echo "${private[*]}") bin/rails masker:run search:reindex"
  else
    echo "== Nothing to mask (demo tenants only) =="
  fi
fi

docker exec -u vscode -w /workspaces/app "$container" sh .devcontainer/post-start.sh
