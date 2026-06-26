#!/usr/bin/env bash
# briefing.sh — Generate and deliver Ben's morning briefing via Slack DM (06:00 daily)
TASK_NAME="briefing"
source "$(dirname "$0")/common.sh"

log "INFO" "=== Starting briefing ==="
acquire_lock

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

run_claude "/briefing"
exit_code=$?

log "INFO" "=== Finished (exit $exit_code) ==="
exit "$exit_code"
