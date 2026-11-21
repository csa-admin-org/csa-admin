#!/bin/sh
# Start the Cursor worker (once logged in) and, with AUTOSTART_DEV=1, bin/dev in the background.
# setsid detaches them from the postStartCommand session, which kills its children.
set -eu
cd /workspaces/app

if [ -e .devcontainer/post-start.local.sh ]; then sh .devcontainer/post-start.local.sh; fi

if [ -f "$HOME/.config/cursor/auth.json" ] && ! pgrep -f "cursor-agent.* worker " >/dev/null; then
  setsid -f bash -lic "exec cursor-agent worker --connect-workspace --idle-release-timeout 0 start" \
    >/tmp/worker.log 2>&1 </dev/null
fi

if [ "${AUTOSTART_DEV:-0}" = 1 ] && ! pgrep -f "puma.*:${PORT:-3000}" >/dev/null; then
  rm -f tmp/pids/server.pid
  setsid -f bash -lic "exec bin/dev -b 0.0.0.0" >log/dev-server.log 2>&1 </dev/null
  echo "bin/dev starting on port ${PORT:-3000} (log/dev-server.log)"
fi
