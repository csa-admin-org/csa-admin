#!/bin/sh
# Runs on the host before each container start (initializeCommand).
set -eu
cd "$(dirname "$0")"

common=$(git rev-parse --path-format=absolute --git-common-dir)
{ grep -v '^GIT_COMMON_DIR=' .env 2>/dev/null || true; echo "GIT_COMMON_DIR=$common"; } >.env.tmp
mv .env.tmp .env
[ -e compose.local.yaml ] || [ -L compose.local.yaml ] || echo 'services: {}' >compose.local.yaml
if [ -e initialize.local.sh ]; then sh initialize.local.sh; fi
